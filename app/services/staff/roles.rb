# frozen_string_literal: true

module Staff
  # What each role can do on the farm. The owner (the person signed in) holds
  # every capability; the others are invited people.
  module Roles
    CAPABILITIES = %w[see_fields edit_data manage_tasks see_reports invite].freeze
    ROLES = {
      "manager" => %w[see_fields edit_data manage_tasks see_reports invite],
      "worker"  => %w[see_fields manage_tasks],
      "viewer"  => %w[see_fields see_reports]
    }.freeze

    module_function

    def keys = ROLES.keys
    def can?(role, capability) = role == "owner" || ROLES.fetch(role, []).include?(capability)
  end
end
