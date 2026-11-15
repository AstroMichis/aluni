module App
  # The authenticated home: the menu dial, the door to every section. The
  # "Ask Aluni" chat (/app/onboarding) is optional; nothing forces it.
  class HomeController < BaseController
    layout "app_screen"

    # The rotation plan for the main field, the app's main result, sits above the dial.
    def show
      field = Fields::Farm.for(Current.user).main_field
      @plan_field = field unless field.nil? || field.empty?
    end
  end
end
