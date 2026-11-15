# The menu sections: full-screen app screens (layouts/app_screen) on the
# signed-in person's farm (Fields::Farm). Every change goes through a service
# and comes back as a redirect that Turbo morphs (scroll kept).
module App
  module FarmScreen
    extend ActiveSupport::Concern

    included do
      layout "app_screen"
      before_action :set_farm
    end

    private

    def set_farm
      @profile = Fields::Profile.current
      @farm = Fields::Farm.for(Current.user)
    end

    # An edit form's answers, shaped as the registry says (lists, the pin, past seasons).
    def form_values(level)
      data = @profile.data(level).select(&:column)
      lists, others = data.partition(&:multiple)
      scalars = others.map { |d| d.key.to_sym } - %i[location crop_history]
      params.fetch(:values, {}).permit(*scalars, location: %i[latitude longitude], crop_history: {},
                                       **lists.to_h { |d| [ d.key.to_sym, [] ] }).to_h
    end

    def form_confirmations = Array(params[:confirm]).map(&:to_s)

    # The field a screen is about: ?field=<id>, else the main field.
    def selected_field = @farm.field(params[:field]) || @farm.main_field

    def save_and_return(result, fallback:)
      case result
      in Result::Success
        redirect_back_or_to fallback, notice: t("app.screens.saved"), status: :see_other
      in Result::Failure(code: :not_found)
        head :not_found
      in Result::Failure(code:)
        redirect_back_or_to fallback, alert: t("app.screens.#{code}", default: t("app.screens.invalid")), status: :see_other
      end
    end
  end
end
