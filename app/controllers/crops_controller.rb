# My crops (section 2): what grows on each field now, the rotation with its
# basic checks and the plan for next season, and the season calendar.
class CropsController < ApplicationController
  include FarmPreview

  def show
  end

  def rotation
  end

  def calendar
    @season = Weather::Season.load
  end

  def plan
    save_and_return Crops::PlanService.call(data: draft.data, field: params[:field], crop: params[:crop]),
                    fallback: rotation_menu_crops_path
  end
end
