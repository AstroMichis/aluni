module App
  # The authenticated home: the menu dial, the door to every section. The
  # "Ask Aluni" chat (/app/onboarding) is optional; nothing forces it.
  class HomeController < BaseController
    layout "app_screen"

    def show; end
  end
end
