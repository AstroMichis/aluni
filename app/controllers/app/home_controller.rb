module App
  # The authenticated home. Until the onboarding chat is complete it only
  # forwards there; afterwards it shows a recap of the profile and the way
  # back to the chat ("Talk to Aluni", a placeholder for the next phase).
  class HomeController < BaseController
    def show
      return redirect_to app_onboarding_path unless Current.user.onboarding_complete?

      @snapshot = Onboarding::ProfileSnapshot.new(user: Current.user).to_h
    end
  end
end
