# Confirm, answer or correct one datum of the farm or a field, in place.
class FieldReadingsController < ApplicationController
  include FarmPreview

  def update
    save_and_return Fields::AnswerService.call(data: draft.data, subject: params[:subject], datum: params[:datum],
                                               value: value_param, confirm: params[:confirm].present?),
                    fallback: menu_fields_path
  end

  private

  def value_param
    value = params[:value]
    value.respond_to?(:permit) ? value.permit(value.keys).to_h : value
  end
end
