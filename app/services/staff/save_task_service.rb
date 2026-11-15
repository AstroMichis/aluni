# frozen_string_literal: true

module Staff
  # Adds a task (a title, an optional field, person and due date), or, with
  # an id, marks it done or open. Takes the farm data, returns the copy.
  class SaveTaskService < ApplicationService
    MAX_TASKS = 50

    def initialize(data:, id: nil, title: nil, field: nil, member: nil, due: nil, done: nil)
      @data = data.deep_dup
      @id = id.presence
      @title = title.to_s.strip
      @field = field.presence
      @member = member.presence
      @due = due.presence
      @done = done
    end

    def call
      tasks = Array(@data["tasks"])
      if @id
        task = tasks.find { |t| t["id"] == @id } or return Failure(code: :not_found)
        task["done"] = ActiveModel::Type::Boolean.new.cast(@done) == true
      else
        attrs = step validated
        return Failure(code: :too_many) if tasks.size >= MAX_TASKS

        tasks << attrs.merge("id" => "t#{tasks.map { |t| t["id"].delete_prefix("t").to_i }.max.to_i + 1}", "done" => false)
      end
      Success(@data.merge("tasks" => tasks))
    end

    private

    def validated
      return Failure(code: :invalid) if @title.blank? || @title.length > 120
      return Failure(code: :invalid) if @field && !@data["fields"].to_h.key?(@field)
      return Failure(code: :invalid) if @member && Array(@data["team"]).none? { |m| m["id"] == @member }
      return Failure(code: :invalid) if @due && !date?(@due)

      Success("title" => @title, "field" => @field, "member" => @member, "due" => @due)
    end

    def date?(value)
      Date.iso8601(value.to_s)
      true
    rescue Date::Error
      false
    end
  end
end
