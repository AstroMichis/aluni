module App
  # My fields (menu section 1): each field with what the farmer said and what
  # the public data sources returned for its pin; one form to edit a field,
  # one button to take every source suggestion, a form to add a field, and
  # where every datum comes from.
  class FieldsController < BaseController
    include FarmScreen

    before_action :set_field, only: %i[show edit update refresh confirm]

    def index
    end

    def show
    end

    def edit
    end

    def update
      case Fields::SaveService.call(user: Current.user, subject: @field.key, values: form_values(:field), confirm: form_confirmations)
      in Result::Success
        redirect_to app_field_path(@field.key), notice: t(".saved"), status: :see_other
      in Result::Failure
        redirect_to edit_app_field_path(@field.key), alert: t("app.screens.invalid"), status: :see_other
      end
    end

    # Takes every suggestion the data sources make for this field.
    def confirm
      keys = @field.readings.select { |r| r.state == :to_confirm }.map { |r| r.datum.key }
      keys << "crop_history" if @field.cdl_proposal.any?
      Fields::SaveService.call(user: Current.user, subject: @field.key, confirm: keys)
      redirect_to app_field_path(@field.key), notice: t(".confirmed", count: keys.size), status: :see_other
    end

    def sources
    end

    def new
    end

    def create
      case Fields::CreateFieldService.call(user: Current.user, **create_params)
      in Result::Success(field)
        redirect_to app_field_path(field), notice: t(".added"), status: :see_other
      in Result::Failure(code: :too_many)
        redirect_to app_fields_path, alert: t(".too_many"), status: :see_other
      in Result::Failure
        redirect_to new_app_field_path, alert: t(".invalid"), status: :see_other
      end
    end

    # Asks the data sources again about this field's pin.
    def refresh
      Fields::FetchObservationsJob.perform_later(@field.record.id) if @field.located?
      redirect_to app_field_path(@field.key, anchor: "data-sources"), notice: t(".queued"), status: :see_other
    end

    private

    def set_field
      @field = @farm.field(params[:id]) or raise ActiveRecord::RecordNotFound
    end

    def create_params
      field = params.fetch(:field, {})
      {
        attributes: field.permit(:name, :latitude, :longitude, :location_source, :area, :area_unit, :irrigation, :water_source).to_h,
        crop: field[:crop], planting_month: field[:planting_month], harvest_month: field[:harvest_month],
        history: field.fetch(:history, {}).permit!.to_h
      }
    end
  end
end
