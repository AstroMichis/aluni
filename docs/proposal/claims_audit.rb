# frozen_string_literal: true

# Recomputes every claim in docs/proposal/claims.yml and compares it with the value the proposal states.
# PASS: the computed number matches what draft 0.3 states ("now"). CHANGED marks numbers that differ from
# draft 0.2 ("was"), so the docx edits can be checked one by one. Evidence claims print their verdict.
# Exits 1 when any number differs from "now" (the doc and the code have drifted apart).
#
# Run after the worked example and the hindcast:
#   mise exec -- ruby docs/proposal/ames_worked_example.rb
#   mise exec -- ruby docs/proposal/validation/run_all.rb
#   mise exec -- ruby docs/proposal/claims_audit.rb

require "json"
require "yaml"

VAL = File.expand_path("validation", __dir__)
we = JSON.parse(File.read(File.expand_path("ames_worked_example_out.json", __dir__)))
v = File.exist?(File.join(VAL, "validation_out.json")) ? JSON.parse(File.read(File.join(VAL, "validation_out.json"))) : {}
y = File.exist?(File.join(VAL, "validation_out_york.json")) ? JSON.parse(File.read(File.join(VAL, "validation_out_york.json"))) : {}
claims = YAML.safe_load_file(File.expand_path("claims.yml", __dir__))

drift = 0
changed = 0
claims.each do |c|
  value = begin
    eval(c["compute"], binding) # rubocop:disable Security/Eval -- expressions come from claims.yml in this repo
  rescue StandardError => e
    "ERROR #{e.class}: #{e.message}"
  end
  if c["kind"] == "number"
    ok = value.is_a?(Numeric) && (value - c["now"]).abs <= c["tol"].to_f
    drift += 1 unless ok
    moved = c["was"] != c["now"]
    changed += 1 if moved
    shown = value.is_a?(Numeric) ? value.round(3) : value
    puts "#{(ok ? "PASS" : "DIFFERS").ljust(10)}#{c['id'].ljust(5)} #{c['text']}: computed #{shown}, doc #{c['now']}#{moved ? "  (CHANGED from #{c['was']})" : ''}"
  else
    puts "#{value.to_s.split(':').first.to_s.ljust(10)}#{c['id'].ljust(5)} #{c['text']}\n#{' ' * 14}#{value}"
  end
end
puts "\n#{claims.size} claims; #{changed} numbers change from draft 0.2 to 0.3; #{drift} differ from the code"
exit(drift.zero? ? 0 : 1)
