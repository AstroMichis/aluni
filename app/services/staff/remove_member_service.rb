# frozen_string_literal: true

module Staff
  # Removes a team member; their open tasks go back to unassigned.
  class RemoveMemberService < ApplicationService
    def initialize(data:, id:)
      @data = data.deep_dup
      @id = id.to_s
    end

    def call
      team = Array(@data["team"])
      return Failure(code: :not_found) unless team.any? { |m| m["id"] == @id }

      tasks = Array(@data["tasks"]).map { |task| task["member"] == @id ? task.merge("member" => nil) : task }
      Success(@data.merge("team" => team.reject { |m| m["id"] == @id }, "tasks" => tasks))
    end
  end
end
