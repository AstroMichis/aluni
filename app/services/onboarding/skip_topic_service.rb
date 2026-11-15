module Onboarding
  # Moves the chat to the next topic without a Gemini call, leaving the
  # transition line as Aluni's turn so a reload shows it. On the last topic it
  # completes the onboarding instead. A staged proposal is left for the card.
  class SkipTopicService < ApplicationService
    def initialize(user:, locale: nil)
      @user = user
      @locale = locale
    end

    def call
      session = step(EnsureProfileService.call(user: @user))[:session]
      next_topic = Topics.next(session.topic)
      return complete(session) unless next_topic

      transition = I18n.t("onboarding.transitions.#{next_topic}", locale: locale_for(session))
      session.topic = next_topic
      session.transcript = (session.transcript + [ model_turn(transition) ]).last(Rails.configuration.x.onboarding.max_turns)
      session.save!
      Success(topic: next_topic, transition: transition, completed: false)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def complete(session)
      step CompleteService.call(user: @user)
      Success(topic: session.topic, transition: nil, completed: true)
    end

    def locale_for(session)
      candidate = (@locale || session.language || @user.locale).to_s
      I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale
    end

    def model_turn(text)
      { "role" => "model", "text" => text, "at" => Time.current.iso8601 }
    end
  end
end
