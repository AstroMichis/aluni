# The public credits page (/credits): every data source, API, method and library Aluni uses,
# with its APA reference, what is read, how and why, its licence and the credit its provider
# asks for. The registry is config/evidence/credits.yml, checked against the code by
# docs/proposal/credits_audit.rb; the words around it are in the locale files.
class CreditsController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  REGISTRY = Rails.root.join("config/evidence/credits.yml")
  GROUPS = %w[nasa data service method software].freeze
  USED_IN = %w[app both backtest].freeze
  AUDIT = [
    "mise exec -- ruby docs/proposal/credits_audit.rb",
    "mise exec -- ruby docs/proposal/credits_audit.rb --online"
  ].freeze

  def self.registry = YAML.safe_load_file(REGISTRY).except("ignore_hosts")

  def show
    @credits = self.class.registry
    @groups = GROUPS.to_h { |group| [ group, @credits.select { |_, c| c["group"] == group } ] }
  end
end
