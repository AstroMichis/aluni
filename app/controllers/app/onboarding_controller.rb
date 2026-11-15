module App
  # The onboarding chat: one page (show) and one Turbo Stream action per turn.
  # Every action pattern matches a Result from app/services/onboarding; the
  # transcript, the staged proposal and the counters live on the person's
  # OnboardingSession row, so a refresh resumes where they were.
  class OnboardingController < BaseController
    before_action :ensure_profile

    def show
      @onboarding_session = Current.user.onboarding_session
      @turns = @onboarding_session.transcript
      @proposal = @onboarding_session.proposal.presence
      @topic = @onboarding_session.topic
      @index, @total = progress_for(@topic)
      @snapshot = snapshot
      @pin = staged_pin(@proposal)
    end

    def message
      case Onboarding::ReplyService.call(user: Current.user, text: params[:text].to_s, locale: I18n.locale, coords: coordinates)
      in Result::Success(payload)
        @payload = payload
        @topic = payload[:topic]
        # The dots are drawn from the topic list itself (0-based); the payload's
        # progress is a 1-based "3 of 8" for other clients.
        @index, @total = progress_for(@topic)
        @pin = staged_pin(payload[:proposal])
        render_stream :message
      in Result::Failure({ code: :blocked })
        @notice_title = t("app.onboarding.show.blocked_title")
        @notice = t("onboarding.blocked")
        render_stream :notice, status: :too_many_requests
      in Result::Failure({ code: :empty })
        head :unprocessable_content
      in Result::Failure(error)
        @notice = extract_error_message(error)
        render_stream :notice, status: :unprocessable_content
      end
    end

    def confirm
      case Onboarding::ApplyProposalService.call(user: Current.user, accepted: accepted_fields)
      in Result::Success
        @notice = t(".saved")
        @snapshot = snapshot
        @topic = Current.user.onboarding_session.topic
        @index, @total = progress_for(@topic)
        @pin = staged_pin(nil)
        render_stream :confirm
      in Result::Failure({ code: :expired })
        @notice = t(".expired")
        render_stream :notice, status: :unprocessable_content
      in Result::Failure({ code: :invalid, messages: })
        @notice = messages.join(", ")
        render_stream :notice, status: :unprocessable_content
      in Result::Failure(error)
        @notice = extract_error_message(error)
        render_stream :notice, status: :unprocessable_content
      end
    end

    def discard
      case Onboarding::DiscardProposalService.call(user: Current.user)
      in Result::Success
        @notice = t(".done")
        render_stream :discard
      in Result::Failure(error)
        @notice = extract_error_message(error)
        render_stream :notice, status: :unprocessable_content
      end
    end

    def skip
      case Onboarding::SkipTopicService.call(user: Current.user, locale: I18n.locale)
      in Result::Success({ topic:, transition:, completed: })
        @topic = topic
        @transition = transition
        @completed = completed
        @index, @total = progress_for(topic)
        @pin = staged_pin(nil)
        render_stream :skip
      in Result::Failure(error)
        @notice = extract_error_message(error)
        render_stream :notice, status: :unprocessable_content
      end
    end

    def complete
      case Onboarding::CompleteService.call(user: Current.user)
      in Result::Success
        redirect_to app_root_path, notice: t(".done"), status: :see_other
      in Result::Failure(error)
        redirect_to app_onboarding_path, alert: extract_error_message(error), status: :see_other
      end
    end

    def reset
      case Onboarding::ResetService.call(user: Current.user)
      in Result::Success
        redirect_to app_onboarding_path, notice: t(".done"), status: :see_other
      in Result::Failure(error)
        redirect_to app_onboarding_path, alert: extract_error_message(error), status: :see_other
      end
    end

    private

    def ensure_profile
      case Onboarding::EnsureProfileService.call(user: Current.user)
      in Result::Success then nil
      in Result::Failure(error)
        redirect_to app_root_path, alert: extract_error_message(error), status: :see_other
      end
    end

    # The chat posts with Accept: text/vnd.turbo-stream.html (chat_controller.js
    # and Turbo forms alike); a plain HTML submit is sent back to the page,
    # which renders the same state from the row.
    def render_stream(template, status: :ok)
      respond_to do |format|
        format.turbo_stream { render template, status: status }
        format.html do
          flash[:alert] = @notice if @notice && status != :ok
          redirect_to app_onboarding_path, status: :see_other
        end
      end
    end

    def snapshot
      Onboarding::ProfileSnapshot.new(user: Current.user).to_h
    end

    # [index, total] for the progress dots, index 0-based (the partial shows index + 1).
    def progress_for(topic)
      [ Onboarding::Topics.index(topic) || 0, Onboarding::Topics.size ]
    end

    # Browser geolocation shared through the composer's hidden fields.
    def coordinates
      latitude = params[:latitude].presence
      longitude = params[:longitude].presence
      return nil unless latitude && longitude

      { latitude: latitude.to_f, longitude: longitude.to_f }
    end

    def accepted_fields
      Array(params[:accepted_fields]).grep(String).first(200)
    end

    # The pin the "is this your area?" picture shows: the one staged in the
    # proposal if any, otherwise the one already saved on the main field.
    def staged_pin(proposal)
      field = (proposal || {}).deep_stringify_keys["field"] || {}
      if field["latitude"].present? && field["longitude"].present?
        return { latitude: field["latitude"].to_f, longitude: field["longitude"].to_f }
      end

      saved = (@snapshot || snapshot)[:field]
      return nil unless saved && saved[:latitude] && saved[:longitude]

      { latitude: saved[:latitude], longitude: saved[:longitude] }
    end
  end
end
