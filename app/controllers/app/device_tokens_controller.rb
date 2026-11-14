module App
  # The native shells register and remove their push token here (bridge
  # components `notification-token` and `push-permission`).
  class DeviceTokensController < BaseController
    def create
      return head :unprocessable_content unless DeviceToken.platforms.key?(params[:platform].to_s) && params[:token].present?

      Current.user.device_tokens.find_or_create_by!(token: params[:token].to_s, platform: params[:platform].to_s)
      head :ok
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      head :unprocessable_content
    end

    def destroy
      Current.user.device_tokens.where(token: params[:token].to_s).destroy_all
      head :ok
    end
  end
end
