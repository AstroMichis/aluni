# The public evidence page for reviewers: the 2001-2025 hindcast that scores the
# decision engine against what happened on one Iowa field (docs/proposal/validation).
# The numbers come from config/evidence/backtest.yml, written by
# docs/proposal/validation/publish.rb; the words are in the locale files.
class EvidenceController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  SNAPSHOT = Rails.root.join("config/evidence/backtest.yml")
  STUDIES = %w[v1 v2 v3 v4 v5 v6 v7 v8].freeze
  QUESTIONS = %w[facts rotation pests operations].freeze
  # The register items the backtest raised, and whether the app has acted on them.
  FIXES = { "u27" => "done", "u28" => "done", "u29" => "done", "u30" => "done", "u31" => "open", "u32" => "open" }.freeze
  PRINCIPLES = %w[preregistered independent unfitted reproducible].freeze
  VERDICT_BADGES = { "PASS" => "success", "FAIL" => "danger", "REPORTED" => "info" }.freeze
  REPRODUCE = [
    "mise exec -- bin/rails runner docs/proposal/validation/fetch.rb",
    "mise exec -- ruby docs/proposal/validation/run_all.rb",
    "mise exec -- ruby docs/proposal/claims_audit.rb"
  ].freeze

  def self.snapshot = YAML.safe_load_file(SNAPSHOT)

  def show
    @snapshot = self.class.snapshot
    @studies = @snapshot.fetch("studies")
  end
end
