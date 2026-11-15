module App
  # "Plan the planting": how one season splits a field between crops, each
  # with its area (or share) and its cells on the field map. One form per
  # season; Fields::SeasonLayoutService saves it.
  class FieldLayoutsController < BaseController
    include FarmScreen

    before_action :set_field_and_year

    def edit
    end

    def update
      case Fields::SeasonLayoutService.call(user: Current.user, field: @field.key, year: @year, crops: crop_params)
      in Result::Success
        redirect_to app_field_path(@field.key), notice: t(".saved", year: @year), status: :see_other
      in Result::Failure(code: :not_found)
        head :not_found
      in Result::Failure(code:)
        redirect_to edit_app_field_layout_path(@field.key, year: @year), alert: t(".errors.#{code}", default: t("app.screens.invalid")),
                                                                          status: :see_other
      end
    end

    private

    def set_field_and_year
      @field = @farm.field(params[:field_id]) or raise ActiveRecord::RecordNotFound
      year = params[:year].to_i
      @year = Fields::SeasonLayoutService.years.cover?(year) ? year : (@field.current_season || Date.current.year)
    end

    # Each row's amount is an area in the field's unit, or a percent when the
    # field has no area (FieldLayoutsHelper#layout_total).
    def crop_params
      rows = params.permit(crops: %i[crop amount cells planting_month harvest_month]).fetch(:crops, [])
      total = helpers.layout_total(@field)
      rows.map do |row|
        row = row.to_h
        row.except("amount").merge("share" => row["amount"].present? ? row["amount"].to_f / total : nil)
      end
    end
  end
end
