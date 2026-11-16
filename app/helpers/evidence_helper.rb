# Formats the hindcast snapshot's numbers for the evidence page's locale strings.
module EvidenceHelper
  MONEY = %w[aluni farmer corn_always foresight].freeze

  # Interpolation values for one study's strings: money with thousands separators,
  # crop keys as their names in this language, month-day pairs as dates.
  def evidence_vars(study)
    study.except("verdict").to_h do |key, value|
      formatted = if MONEY.include?(key) then number_with_delimiter(value)
      elsif value.is_a?(Array) then value.map { |crop| t("app.crops.names.#{crop}", default: crop) }.to_sentence
      elsif key.start_with?("planted_") && value.is_a?(String) then l(Date.strptime("2001-#{value}", "%Y-%m-%d"), format: "%-d %b")
      elsif value.is_a?(Float) then number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
      else value
      end
      [ key.to_sym, formatted ]
    end
  end

  # One study's numbers from the snapshot, read once per process.
  def evidence_study(id) = (EvidenceHelper.snapshot["studies"] || {}).fetch(id.to_s, {})

  def self.snapshot = @snapshot ||= EvidenceController.snapshot

  def evidence_badge(verdict) = "badge badge--#{EvidenceController::VERDICT_BADGES.fetch(verdict.to_s, 'info')}"
end
