# frozen_string_literal: true

module Fields
  # SMAP polls queued before Fields::FetchAppeearsJob took every AppEEARS
  # source (2026-11-15) still name this class; it forwards them. Safe to delete
  # once no FetchSoilMoistureJob is left in the queues (a few hours after deploy).
  class FetchSoilMoistureJob < FetchAppeearsJob
    def perform(field_id, task_id: nil, polls: 0) = super(field_id, source: "smap", task_id: task_id, polls: polls)
  end
end
