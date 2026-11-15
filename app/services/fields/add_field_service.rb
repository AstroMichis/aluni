# frozen_string_literal: true

module Fields
  # Adds the field the person described in the add-a-field conversation.
  # Starting from the sample farm, the answers start a farm of their own (the
  # sample, its team and tasks are left behind; every weather alert is on); otherwise the field joins their farm and the farm
  # answers stay as they were. Takes the farm data, returns [data, field key].
  class AddFieldService < ApplicationService
    MAX_FIELDS = 8

    def initialize(data:, answers:, confirmed: [], profile: Profile.current)
      @data = data["sample"] ? { "answers" => {}, "confirmed" => [], "fields" => {}, "alerts" => Weather::AlertsService::KINDS.dup } : data.deep_dup
      @answers = answers.to_h.transform_keys(&:to_s)
      @confirmed = Array(confirmed).map(&:to_s)
      @profile = profile
    end

    def call
      fields = @data["fields"] ||= {}
      return Failure(code: :too_many) if fields.size >= MAX_FIELDS

      key = "f#{fields.size + 1}"
      # The first field sits at the preview's one measured point (the snapshot).
      fields[key] = { "answers" => {}, "confirmed" => @confirmed & keys(:field), "snapshot" => fields.none? { |_, f| f["snapshot"] } }
      @data["confirmed"] = Array(@data["confirmed"]) | (@confirmed & keys(:farm))
      apply("farm", @profile.data(:farm).reject { |d| @data["answers"].key?(d.key) })
      apply(key, @profile.data(:field))

      Success([ @data, key ])
    end

    private

    def keys(level) = @profile.data(level).map(&:key)

    # Keeps each answer that AnswerService accepts; blank or invalid ones stay unanswered.
    def apply(subject, data)
      data.each do |datum|
        next if @answers[datum.key].blank?

        result = AnswerService.call(data: @data, subject: subject, datum: datum.key, value: @answers[datum.key], profile: @profile)
        @data = result.value if result.success?
      end
    end
  end
end
