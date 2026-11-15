module App
  # The authenticated home: a recap of what is known about the farm (the field
  # finder wrote it at sign-up, or nothing yet) and the way to "Ask Aluni"
  # (/app/onboarding), which is optional. Nothing forces a chat.
  class HomeController < BaseController
    def show
      @snapshot = Onboarding::ProfileSnapshot.new(user: Current.user).to_h
    end
  end
end
