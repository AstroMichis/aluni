# frozen_string_literal: true

module Staff
  # Removes a task. Takes the farm data, returns the copy.
  class RemoveTaskService < ApplicationService
    def initialize(data:, id:)
      @data = data.deep_dup
      @id = id.to_s
    end

    def call
      tasks = Array(@data["tasks"])
      return Failure(code: :not_found) unless tasks.any? { |t| t["id"] == @id }

      Success(@data.merge("tasks" => tasks.reject { |t| t["id"] == @id }))
    end
  end
end
