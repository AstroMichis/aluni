# The menu sections' web preview: the farm comes from the session draft
# (Fields::Draft), and every change goes through a service that returns the
# new farm data, which is saved and the page reloaded (Turbo morphs it).
module FarmPreview
  extend ActiveSupport::Concern

  included do
    allow_unauthenticated_access
    layout "public"
    before_action :set_farm
  end

  private

  def draft = @draft ||= Fields::Draft.new(session)

  def set_farm
    @profile = Fields::Profile.current
    @farm = draft.farm
  end

  def save_and_return(result, fallback:)
    case result
    in Result::Success(data)
      draft.save(data)
      redirect_back_or_to fallback, notice: t("preview.saved"), status: :see_other
    in Result::Failure(code: :not_found)
      head :not_found
    in Result::Failure(code:)
      redirect_back_or_to fallback, alert: t("preview.#{code}", default: t("preview.invalid")), status: :see_other
    end
  end
end
