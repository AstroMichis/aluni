module App
  # The authenticated home. Until the onboarding chat is complete it forwards
  # there; afterwards it is the menu dial, the door to every section.
  class HomeController < BaseController
    layout "app_screen"

    def show
      redirect_to app_onboarding_path unless Current.user.onboarding_complete?
    end
  end
end
