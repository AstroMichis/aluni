module Onboarding
  # One turn of the onboarding chat. Stores the farmer's (redacted) message,
  # drafts Aluni's answer with Gemini while an intent classifier runs beside
  # it, stages the facts the answer carried for the confirm card, moves the
  # topic forward and persists the transcript. Only the guards are Failures
  # (:blocked, :empty); every Gemini problem is a Success in character, either
  # a refusal (refusal: true) or a continuation line (degraded: true), so the
  # person waiting on the page always gets a bubble.
  #
  #   Onboarding::ReplyService.call(user:, text:, locale:, coords: { latitude:, longitude: })
  #   => Success(user_text:, assistant_text:, transition:, topic:, topic_complete:, proposal:,
  #              progress: { index:, total: }, completed:, degraded:, refusal:)
  class ReplyService < ApplicationService
    USER = "user"
    MODEL = "model"
    PENDING_MAX = 2000
    CONFIDENT = %w[medium high].freeze

    def initialize(user:, text:, locale:, coords: nil)
      @user = user
      @text = text
      @locale = available_locale(locale)
      @coords = coords
      @session = nil
    end

    def call
      @session = step load_session
      @redacted = Redactor.redact(@text)
      return Failure(code: :empty) if @redacted.blank?

      replayed = take_pending
      append_turn(USER, @redacted)
      context = build_context(replayed)
      classification, draft = ask(context)
      Success(resolve(classification, draft, replayed))
    rescue StandardError => e
      Rails.logger.error("[Onboarding::ReplyService] #{e.class}: #{e.message}")
      Success(degrade(replayed))
    end

    private

    def config = Rails.configuration.x.onboarding

    def load_session
      session = step(EnsureProfileService.call(user: @user))[:session]
      return Failure(code: :blocked, blocked_until: session.blocked_until) if session.blocked?

      Success(session)
    end

    # A message Aluni could not answer last time is replayed into this turn's
    # request so the model addresses it; the transcript keeps what was typed.
    def take_pending
      pending = @session.pending_message.presence
      @session.pending_message = nil
      pending
    end

    def append_turn(role, text)
      turn = { "role" => role, "text" => text, "at" => Time.current.iso8601 }
      @session.transcript = (@session.transcript + [ turn ]).last(config.max_turns)
    end

    # Every database read happens here, on the request thread.
    def build_context(replayed)
      snapshot = ProfileSnapshot.new(user: @user)
      opening = @session.turns_count.zero? ? t("onboarding.welcome_message", name: @user.display_name) : nil
      system = SystemPrompt.build(snapshot: snapshot, topic: @session.topic, locale: @locale,
                                  display_name: @user.display_name, opening: opening)
      { system: system, contents: contents(replayed) }
    end

    # The last context_turns as alternating user/model contents (Gemini wants
    # a user turn first and one content per speaker in a row).
    def contents(replayed)
      turns = @session.transcript.last(config.context_turns).drop_while { |turn| turn["role"] != USER }
      merged = turns.each_with_object([]) do |turn, out|
        role = turn["role"] == USER ? USER : MODEL
        if out.last && out.last[:role] == role
          out.last[:parts][0][:text] = "#{out.last[:parts][0][:text]}\n#{turn['text']}"
        else
          out << { role: role, parts: [ { text: turn["text"].to_s } ] }
        end
      end
      if replayed && merged.last && merged.last[:role] == USER
        merged.last[:parts][0][:text] = "#{replayed}\n#{merged.last[:parts][0][:text]}"
      end
      merged
    end

    # The classifier runs in its own thread with its own client while the
    # draft runs here; an unfinished classifier counts as safe.
    def ask(context)
      draft_client = Gemini::Client.new(model: :flash, timeout: config.gemini_timeout)
      classifier = classify_in_background
      draft = DraftReplyService.call(messages: context[:contents], system_instruction: context[:system], client: draft_client)
      [ await_classification(classifier), draft ]
    end

    def classify_in_background
      text = @redacted
      classifier = ClassifyIntentService
      thread = Thread.new do
        Rails.application.executor.wrap { classifier.call(text: text) }
      rescue StandardError => e
        Rails.logger.warn("[Onboarding::ReplyService] classifier failed, counting as safe: #{e.class}: #{e.message}")
        Result::Success.new(ClassifyIntentService::SAFE)
      end
      thread.report_on_exception = false
      thread
    end

    def await_classification(thread)
      finished = ActiveSupport::Dependencies.interlock.permit_concurrent_loads { thread.join(config.gemini_timeout) }
      Rails.logger.warn("[Onboarding::ReplyService] classifier did not finish in time, counting as safe") unless finished
      verdict = finished ? thread.value&.value : nil
      verdict.is_a?(Hash) ? ClassifyIntentService::SAFE.merge(verdict) : ClassifyIntentService::SAFE
    rescue StandardError => e
      Rails.logger.warn("[Onboarding::ReplyService] classifier unreadable, counting as safe: #{e.class}: #{e.message}")
      ClassifyIntentService::SAFE
    end

    def resolve(classification, draft, replayed)
      if classification[:safe] == false
        refuse(classification[:abuse_type])
      elsif draft.failure?
        Rails.logger.warn("[Onboarding::ReplyService] draft failed (#{draft.error[:code]}), continuing in character")
        degrade(replayed)
      else
        accept(draft.value)
      end
    end

    def refuse(abuse_type)
      @session.strikes += 1
      @session.blocked_until = config.block_ttl.from_now if @session.strikes >= config.strike_limit
      text = if @session.blocked?
        t("onboarding.blocked")
      else
        t("onboarding.refusals.#{abuse_type}", default: :"onboarding.refusals.off_topic_hostile")
      end
      finish(text, nil)
      payload(assistant_text: text, refusal: true)
    end

    def accept(draft)
      @session.proposal = stage(draft)
      complete = draft["topic_complete"] == true
      next_topic = complete ? Topics.next(@session.topic) : nil
      completing = complete && next_topic.nil?
      transition = nil
      if next_topic
        @session.topic = next_topic
        transition = t("onboarding.transitions.#{next_topic}")
      end
      text = draft["response_text"].to_s.strip
      finish(text, transition)
      complete_onboarding if completing
      payload(assistant_text: text, transition: transition, topic_complete: complete)
    end

    def complete_onboarding
      result = CompleteService.call(user: @user)
      Rails.logger.error("[Onboarding::ReplyService] completion failed: #{result.error.inspect}") if result.failure?
      @session.reload
    end

    # Facts the farmer said, filtered through the allowlist, plus the pin from
    # the browser (confirmed) or from a confident location guess (approximate).
    def stage(draft)
      updates = Allowlist.filter(draft["updates"])
      field = (updates["field"] || {}).except(*Allowlist::LOCATION_KEYS)
      pin = coords_pin || guess_pin(draft["location_guess"])
      field = field.merge(pin) if pin
      field.any? ? updates.merge("field" => field) : updates.except("field")
    end

    def coords_pin
      return nil unless @coords.respond_to?(:to_h)

      coords = @coords.to_h.with_indifferent_access
      latitude = Allowlist.coerce(coords[:latitude], :latitude)
      longitude = Allowlist.coerce(coords[:longitude], :longitude)
      return nil unless latitude && longitude

      source = coords[:source].to_s == "map" ? "map" : "geolocation"
      { "latitude" => latitude, "longitude" => longitude, "location_confidence" => "confirmed", "location_source" => source }
    end

    def guess_pin(guess)
      return nil unless guess.is_a?(Hash) && CONFIDENT.include?(guess["confidence"].to_s)

      latitude = Allowlist.coerce(guess["latitude"], :latitude)
      longitude = Allowlist.coerce(guess["longitude"], :longitude)
      return nil unless latitude && longitude

      pin = { "latitude" => latitude, "longitude" => longitude, "location_confidence" => "approximate", "location_source" => "assistant" }
      label = Allowlist.coerce(guess["label"], :text)
      pin["place_label"] = label if label
      pin
    end

    # Aluni could not answer: a continuation line in character, the message
    # kept for the next turn, and the user turn stays in the transcript.
    def degrade(replayed)
      text = continuation_line
      if @session
        begin
          @session.pending_message = [ replayed, @redacted ].compact.join("\n").last(PENDING_MAX)
          @session.fallbacks_count += 1
          finish(text, nil)
        rescue StandardError => e
          Rails.logger.error("[Onboarding::ReplyService] could not save the degraded turn: #{e.class}: #{e.message}")
        end
      end
      payload(assistant_text: text, degraded: true)
    end

    def continuation_line
      topic = @session&.topic || Topics.first
      value = I18n.t("onboarding.continuations.#{topic}", locale: @locale, default: "")
      lines = value.is_a?(Array) ? value.map(&:to_s).reject(&:blank?) : []
      return t("onboarding.error_fallback") if lines.empty?

      lines[(@session&.fallbacks_count || 0) % lines.size]
    end

    def finish(text, transition)
      append_turn(MODEL, [ text, transition ].compact.join("\n"))
      @session.turns_count += 1
      @session.last_message_at = Time.current
      @session.language = @locale
      @session.save!
    end

    def payload(assistant_text:, transition: nil, topic_complete: false, degraded: false, refusal: false)
      topic = @session&.topic || Topics.first
      {
        user_text: @redacted,
        assistant_text: assistant_text,
        transition: transition,
        topic: topic,
        topic_complete: topic_complete,
        proposal: @session&.proposal.presence,
        progress: { index: (Topics.index(topic) || 0) + 1, total: Topics.size },
        completed: @session&.completed? || false,
        degraded: degraded,
        refusal: refusal
      }
    end

    def t(key, **options) = I18n.t(key, locale: @locale, **options)

    def available_locale(locale)
      candidate = locale.to_s
      I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale.to_s
    end
  end
end
