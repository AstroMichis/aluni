module App
  # My farm: the farmer's profile and the farm, read and edited in one form.
  class FarmsController < BaseController
    include FarmScreen

    def show
    end

    def edit
    end

    def update
      case Fields::SaveService.call(user: Current.user, subject: "farm", values: form_values(:farm))
      in Result::Success
        redirect_to params[:return_to] == "team" ? app_team_path : app_farm_path, notice: t(".saved"), status: :see_other
      in Result::Failure
        redirect_to edit_app_farm_path, alert: t("app.screens.invalid"), status: :see_other
      end
    end
  end
end
