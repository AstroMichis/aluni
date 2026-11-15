# frozen_string_literal: true

# My crops: how a season reads ("2024", "This season", "Planned").
module CropsHelper
  def season_kind(label) = label.match?(/\A\d+\z/) ? "past" : label
  def season_label(label) = season_kind(label) == "past" ? label : t("app.crops.rotation.labels.#{label}")
end
