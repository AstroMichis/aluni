# frozen_string_literal: true

# Presentation for the rotation comparison: strategy names, the seasons,
# evidence lines with their source, and the facts handed to the narration.
module RotationsHelper
  def strategy_title(strategy) = t("app.rotations.strategies.#{strategy.key}.title")

  # The rule-based "why", shown until (or instead of) the written one.
  def strategy_why(strategy)
    why = strategy.why
    lead = why[:lead] ? t("app.rotations.criteria.#{why[:lead]}.short") : nil
    t("app.rotations.strategies.#{strategy.key}.why", crop: crop_name(why[:crop]), lead: lead)
  end

  def season_years(count = Rotations::Comparator::HORIZON) = Array.new(count) { |i| Date.current.year + 1 + i }

  def fact_text(fact)
    values = fact.values.transform_values { |v| v.is_a?(String) && Crops::Agronomy.find(v) ? crop_name(v) : v }
    values[:class] = t("app.crops.suitability.#{values[:class]}") if values[:class]
    values[:months] = values[:months].map { |m| t("date.month_names")[m] }.to_sentence if values[:months].is_a?(Array)
    if (attribute = fact.key.to_s.delete_prefix("soil_")).in?(Rotations::Comparator::SOIL_FACTORS)
      values[:value] = value_label(attribute, values[:value]).downcase
      values[:need] = ecocrop_class(attribute, values[:need]).downcase
    end
    values[:source] = value_label("water_source", values[:source]).downcase if fact.key == "irrigation_supply"
    t("app.rotations.evidence.#{fact.key}", **values)
  end

  # An ECOCROP class ("medium (50-150 cm)", "poorly (saturated >50% of year)") in the
  # farmer's words for the same attribute, keeping ECOCROP's own detail in brackets.
  def ecocrop_class(attribute, text)
    word = text.to_s[/\A[a-z]+/].to_s
    label = value_label(attribute, { "poorly" => "poor", "excessively" => "excessive" }.fetch(word, word))
    detail = text.to_s[/\((.*)\)/, 1]
    detail ? "#{label} (#{detail})" : label
  end

  def score_text(value) = value.nil? ? t("app.rotations.no_data") : t("app.rotations.score", value: value)

  # What the narration may use: names in the farmer's language, nothing else.
  def narration_facts(strategy, comparator)
    {
      strategy: strategy_title(strategy), seasons: strategy.crops.map { |c| crop_name(c) },
      strongest_point: strategy.why[:lead] && t("app.rotations.criteria.#{strategy.why[:lead]}.short"),
      better_than_current_in: strategy.benefits.map { |c| t("app.rotations.criteria.#{c}.short") },
      evidence: strategy.evidence.map { |f| fact_text(f) },
      risks: strategy.risks.map { |r| t("app.rotations.risks.#{r}") },
      farmer_goals: Array(Current.user.farmer_profile&.goals).map { |g| value_label("goals", g) }
    }
  end
end
