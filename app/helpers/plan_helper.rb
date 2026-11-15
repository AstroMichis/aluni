# frozen_string_literal: true

# Formatting for the action plan page (/plan): the evidence labels in the proposal's text
# ([VERIFIED: ...], [UNKNOWN], [DESIGN], [ASSUMPTION A-n]) get a visual marker. The text
# itself is unchanged and escaped before any markup is added.
module PlanHelper
  EVIDENCE_LABEL = /\[(VERIFIED \(secondary\)|VERIFIED|UNKNOWN|DESIGN|ASSUMPTION)\b[^\]]*\]/

  LABEL_KINDS = {
    "VERIFIED (secondary)" => "secondary", "VERIFIED" => "verified", "UNKNOWN" => "unknown",
    "DESIGN" => "design", "ASSUMPTION" => "assumption"
  }.freeze

  def plan_text(text)
    String.new(ERB::Util.html_escape(text.to_s)).gsub(EVIDENCE_LABEL) do |label|
      %(<span class="plan__label plan__label--#{LABEL_KINDS.fetch($1)}">#{label}</span>)
    end.html_safe
  end
end
