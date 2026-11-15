module App
  # The field finder's "Save field" for a signed-in farmer: PATCH /app/fields/:id
  # with the finder's flat keys. The id names the main field (it must be one of
  # the person's); the writes themselves go through Fields::SaveSetupService,
  # the same path a sign-up takes.
  class FieldsController < BaseController
    def update
      field = Current.user.farms.first&.fields&.find(params[:id])
      return head :not_found unless field

      case Fields::SaveSetupService.call(user: Current.user, attributes: field_attributes)
      in Result::Success
        redirect_to app_root_path, notice: t(".saved"), status: :see_other
      in Result::Failure(error)
        redirect_back fallback_location: root_path, alert: extract_error_message(error), status: :see_other
      end
    end

    private

    def field_attributes
      params.permit(*Fields::SaveSetupService::KEYS).to_h
    end
  end
end
