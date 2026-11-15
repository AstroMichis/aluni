module App
  # The rotation comparison for one piece of a field (Rotations::Comparator on
  # a Fields::Zone, ?zone= by index; a field never split is one zone): the
  # current rotation against the alternatives, each with its scores, evidence,
  # benefits, gaps and risks. "Why" is written by Rotations::NarrateService in
  # a lazy frame; the page shows the rule-based text until it arrives.
  class RotationsController < BaseController
    include FarmScreen

    before_action do
      @field = @farm.field(params[:field_id]) or raise ActiveRecord::RecordNotFound
      @zone = @field.zone(params[:zone])
      @scenario = Weather::Scenario.find(params[:scenario])
      @comparator = Rotations::Comparator.new(@zone, profile: Current.user.farmer_profile, scenario: @scenario)
    end

    def show
    end

    def why
      strategy = @comparator.strategies.find { |s| s.key == params[:strategy] } or return head :not_found
      text = Rotations::NarrateService.call(facts: helpers.narration_facts(strategy, @comparator), locale: I18n.locale).value_or(nil)
      render partial: "app/rotations/why", locals: { strategy: strategy, text: text }, layout: false
    end
  end
end
