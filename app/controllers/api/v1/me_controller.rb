module Api
  module V1
    class MeController < BaseController
      def show
        render json: {
          id: current_user.id,
          display_name: current_user.display_name,
          email_address: current_user.email_address,
          locale: current_user.locale,
          passkeys_count: current_user.passkeys.count
        }
      end
    end
  end
end
