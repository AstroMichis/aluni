# Google, Apple or Microsoft linked to the signed-in account: disconnect one,
# never the last way in (Auth::DisconnectIdentityService). Connecting is a POST
# to /auth/:provider with intent=connect (passkeys/index).
class IdentitiesController < ApplicationController
  include NativeOnly

  def destroy
    identity = Current.user.identities.find_by(id: params[:id])
    case Auth::DisconnectIdentityService.call(user: Current.user, identity: identity)
    in Result::Success({ identity: })
      redirect_to passkeys_path, notice: t(".removed", provider: t("omniauth_callbacks.providers.#{identity.provider}")), status: :see_other
    in Result::Failure({ code: :last_way_in })
      redirect_to passkeys_path, alert: t(".last_way_in"), status: :see_other
    in Result::Failure
      head :not_found
    end
  end
end
