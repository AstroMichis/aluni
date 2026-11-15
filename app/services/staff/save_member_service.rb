# frozen_string_literal: true

module Staff
  # Adds a team member, or updates one when an id is given: a name, a role
  # and the fields they work on. Takes the farm data, returns the copy.
  class SaveMemberService < ApplicationService
    MAX_MEMBERS = 20

    def initialize(data:, name: nil, role:, fields: [], id: nil)
      @data = data.deep_dup
      @id = id.presence
      @name = name.to_s.strip
      @role = role.to_s
      @fields = Array(fields).map(&:to_s) & @data["fields"].to_h.keys
    end

    def call
      return Failure(code: :invalid) unless Roles.keys.include?(@role)

      team = Array(@data["team"])
      if @id
        member = team.find { |m| m["id"] == @id } or return Failure(code: :not_found)
        member.merge!("role" => @role, "fields" => @fields)
        member["name"] = @name if @name.present?
      else
        return Failure(code: :invalid) if @name.blank? || @name.length > 60
        return Failure(code: :too_many) if team.size >= MAX_MEMBERS

        team << { "id" => next_id(team, "m"), "name" => @name, "role" => @role, "fields" => @fields }
      end
      Success(@data.merge("team" => team))
    end

    private

    def next_id(list, prefix) = "#{prefix}#{list.map { |item| item["id"].delete_prefix(prefix).to_i }.max.to_i + 1}"
  end
end
