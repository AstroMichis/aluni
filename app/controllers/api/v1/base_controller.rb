module Api
  module V1
    # JSON API for native screens. Authenticates with the same signed session
    # cookie the web views carry; writes need the X-Aluni-Native header instead
    # of a CSRF token (a browser form cannot set a custom header cross-site).
    class BaseController < ActionController::API
      include ActionController::Cookies

      NATIVE_HEADER = "X-Aluni-Native"

      before_action :require_native_header, unless: -> { request.get? || request.head? }
      before_action :authenticate!

      private

      def require_native_header
        head :forbidden unless request.headers[NATIVE_HEADER] == "1"
      end

      def authenticate!
        Current.session = Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
        render json: { error: "unauthorized" }, status: :unauthorized unless Current.session
      end

      def current_user = Current.user
    end
  end
end
