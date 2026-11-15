# My fields (section 1 of the menu): the farm, its fields, the add-a-field
# conversation and where each datum comes from. A web preview: the person's
# answers live in the session (Fields::Draft), the sample farm shows until
# they add a field of their own.
class FieldsController < ApplicationController
  include FarmPreview

  def index
  end

  def show
    @field = @farm.field(params[:id]) or raise ActiveRecord::RecordNotFound
  end

  def farm
  end

  def sources
  end

  # The conversation skips what the farm already answered.
  def new
    @steps = @profile.steps.select { |step| @farm.needs?(step) }
  end

  def create
    case Fields::AddFieldService.call(data: draft.data, answers: answer_params, confirmed: params[:confirmed])
    in Result::Success([data, key])
      draft.save(data)
      redirect_to menu_field_path(key), notice: t(".added"), status: :see_other
    in Result::Failure(code: :too_many)
      redirect_to menu_fields_path, alert: t(".too_many"), status: :see_other
    end
  end

  # Back to the sample farm.
  def reset
    draft.reset!
    redirect_to menu_fields_path, notice: t(".reset"), status: :see_other
  end

  private

  # Every asked datum, scalars and lists as the registry says; the service checks the values.
  def answer_params
    data = @profile.data(:farm) + @profile.data(:field)
    lists, scalars = data.partition(&:multiple)
    params.fetch(:answers, {}).permit(*scalars.map { |d| d.key.to_sym } - [ :crop_history ],
                                      **lists.to_h { |d| [ d.key.to_sym, [] ] }, crop_history: {})
  end
end
