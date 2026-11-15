module App
  # My crops (menu section 2): what grows on each field with its FAO GAEZ
  # potential and ECOCROP fit, the rotation with its basic checks and next
  # season's plan, and the calendar against the frost-free stretch.
  class CropsController < BaseController
    include FarmScreen

    def show
    end

    def rotation
    end

    # The frost-free stretch at the main field's pin frames every field's season.
    def calendar
      @season = Weather::Season.for(@farm.main_field&.observation("nasa_power"))
    end

    def plan
      save_and_return Crops::PlanService.call(user: Current.user, field: params[:field], crop: params[:crop]),
                      fallback: rotation_app_crops_path
    end
  end
end
