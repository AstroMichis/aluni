# Operator kill switch for the browser side of the product. Sign-in, sign-up,
# passkey management and /app answer to browsers and to the Hotwire Native
# shells alike while NATIVE_WEB_ACCESS is on (the default). Turning it off
# (Platform::Features.native_web_access? false) sends browsers back to the
# landing page with a notice and answers JSON with 403; the shells
# (turbo-rails' hotwire_native_app?, a user-agent check) keep working.
#
# This is a product switch, not a security boundary: the session cookie and
# the passkey ceremony are the boundary.
module NativeOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_native_app
  end

  private

  def require_native_app
    return if hotwire_native_app? || Platform::Features.native_web_access?

    respond_to do |format|
      format.html { redirect_to root_path, notice: t("native_only.notice") }
      format.any { head :forbidden }
    end
  end
end
