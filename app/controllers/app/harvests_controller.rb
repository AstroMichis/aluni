module App
  # What one crop in one season yielded and earned, in the farmer's own units:
  # the yields the reports show before the FAO GAEZ reference, and the margin
  # the rotation comparison shows without scoring it (docs/proposal V3, V7).
  class HarvestsController < BaseController
    include FarmScreen

    before_action :set_crop

    def edit
    end

    def update
      case Fields::RecordHarvestService.call(user: Current.user, crop_id: @crop.id, values: harvest_params)
      in Result::Success
        redirect_to harvest_app_reports_path, notice: t(".saved", crop: helpers.crop_name(@crop), year: @crop.season_year), status: :see_other
      in Result::Failure(code: :not_found)
        head :not_found
      in Result::Failure
        redirect_to edit_app_field_harvest_path(@field.key, @crop), alert: t("app.screens.invalid"), status: :see_other
      end
    end

    private

    def set_crop
      @field = @farm.field(params[:field_id]) or raise ActiveRecord::RecordNotFound
      @crop = @field.record.field_crops.find(params[:id])
    end

    def harvest_params = params.fetch(:harvest, {}).permit(*Fields::RecordHarvestService::FIELDS)
  end
end
