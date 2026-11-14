# Soft gate for the native-first split: sign-in, sign-up, passkey management
# and /app answer only to the Hotwire Native shells (turbo-rails'
# hotwire_native_app?, a user-agent check) unless NATIVE_WEB_ACCESS opens them
# to browsers (Platform::Features.native_web_access?, on in development).
#
# This is a product gate, not a security boundary: the session cookie and the
# passkey ceremony are the boundary.
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
