# Sign-in or sign-up with a code sent by email. One unified flow: the server
# never says whether an address has an account; the answer to a typed code is
# what decides between signing in and creating the account. Every POST answers
# a Turbo Stream that replaces the "auth" frame (the finder, /sign_in and
# /sign_up all host one), or the full page without JavaScript.
class SignInCodesController < ApplicationController
  include NativeOnly

  MODES = %w[sign_in sign_up finder].freeze

  allow_unauthenticated_access
  before_action :redirect_if_authenticated, only: :show
  layout "public"

  def show
    @mode = requested_mode
    @stage = :choice
  end

  def create
    request_code(destination: params[:email].to_s, locale: chosen_locale, pending: pending_from_params)
  end

  def verify
    record = current_code
    case Auth::VerifyCodeService.call(sign_in_code: record, code: params[:code].to_s, ip: request.remote_ip)
    in Result::Success({ user: User => user })
      sign_in(user)
    in Result::Success({ sign_in_code: })
      if sign_in_code.pending["display_name"].present?
        complete_account(sign_in_code, sign_in_code.pending["display_name"])
      else
        render_stage(:name, destination: sign_in_code.destination)
      end
    in Result::Failure({ code: :wrong, attempts_left: })
      render_stage(:code, destination: record.destination, resend_after: record.resend_after, attempts_left: attempts_left,
                          error: :wrong, status: :unprocessable_content)
    in Result::Failure({ code: :signups_closed })
      forget_code
      render_stage(:choice, error: :signups_closed, status: :unprocessable_content)
    in Result::Failure(_)
      forget_code
      render_stage(:choice, error: :expired, status: :unprocessable_content)
    end
  end

  def resend
    record = current_code
    return render_stage(:choice, error: :expired, status: :unprocessable_content) unless record

    if record.resend_after.positive?
      render_stage(:code, destination: record.destination, resend_after: record.resend_after)
    else
      request_code(destination: record.destination, locale: record.locale, pending: record.pending)
    end
  end

  def complete
    record = current_code
    return render_stage(:choice, error: :expired, status: :unprocessable_content) unless record

    complete_account(record, params[:display_name].to_s)
  end

  # The link from the mail. In the browser that asked it signs in through the
  # same verification; anywhere else it shows the code to type back.
  def link
    payload = Auth::LinkToken.read(params[:token])
    record = payload && SignInCode.find_by(id: payload["id"])
    return render_expired_link unless record

    if session[:sign_in_code_id] == record.id
      params[:code] = payload["code"]
      verify
    else
      @code = "#{payload["code"][0, 3]} #{payload["code"][3, 3]}"
      @destination = record.destination
      render :link
    end
  end

  private

  def request_code(destination:, locale:, pending:)
    case Auth::RequestCodeService.call(destination: destination, locale: locale, ip: request.remote_ip, pending: pending)
    in Result::Success({ sign_in_code:, resend_after: })
      session[:sign_in_code_id] = sign_in_code.id
      render_stage(:code, destination: sign_in_code.destination, resend_after: resend_after)
    in Result::Failure({ code: })
      render_stage(:choice, error: code, status: :unprocessable_content)
    end
  end

  def complete_account(record, name)
    case Auth::CreateAccountService.call(sign_in_code: record, display_name: name, ip: request.remote_ip)
    in Result::Success({ user: })
      sign_in(user)
    in Result::Failure({ code: :name_required })
      render_stage(:name, destination: record.destination, error: :name_required, status: :unprocessable_content)
    in Result::Failure({ code: :signups_closed })
      forget_code
      render_stage(:choice, error: :signups_closed, status: :unprocessable_content)
    in Result::Failure(_)
      forget_code
      render_stage(:choice, error: :expired, status: :unprocessable_content)
    end
  end

  def sign_in(user)
    forget_code
    start_new_session_for(user, sign_in_method: "email_code")
    cookies.permanent[:locale] = I18n.locale.to_s
    flash[:suggest_passkey] = true if user.passkeys.none?
    redirect_to after_authentication_url, status: :see_other
  end

  # Renders the "auth" frame as a Turbo Stream (any status) or the full page.
  def render_stage(stage, status: :ok, destination: nil, resend_after: 0, attempts_left: nil, error: nil)
    @stage = stage
    @mode = requested_mode
    @destination = destination
    @resend_after = resend_after
    @attempts_left = attempts_left
    @error = error
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("auth", partial: "sign_in_codes/frame"), status: status }
      format.html { render :show, status: status }
    end
  end

  def render_expired_link
    @stage = :choice
    @mode = "sign_in"
    @error = :expired
    render :show, status: :unprocessable_content
  end

  def current_code
    SignInCode.find_by(id: session[:sign_in_code_id])
  end

  def forget_code
    session.delete(:sign_in_code_id)
  end

  def requested_mode
    value = request.request_parameters["mode"].presence || params[:mode].presence
    MODES.include?(value.to_s) ? value.to_s : "sign_in"
  end

  # params[:locale] is the URL segment; the forms post their own.
  def chosen_locale
    value = request.request_parameters["locale"].to_s
    I18n.available_locales.map(&:to_s).include?(value) ? value : I18n.locale.to_s
  end

  def pending_from_params
    body = request.request_parameters
    {
      "display_name" => body["display_name"],
      "locale" => chosen_locale,
      "field" => Fields::SaveSetupService.coerce(body.slice(*Fields::SaveSetupService::KEYS))
    }.compact
  end
end
