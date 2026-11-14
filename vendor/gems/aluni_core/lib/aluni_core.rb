# frozen_string_literal: true

require_relative "aluni_core/version"

# Ruby-visible surface of the Rust extension (ext/aluni_core/src/lib.rs):
#   AluniCore.normalize(string) -> String  (raises ArgumentError on empty input)
# Nothing outside app/services/core calls this module directly.
#
# Bundler does not compile a path gem's extension on `bundle install`, so a
# fresh checkout boots before `bin/rails core:compile` has run. Instead of
# failing the whole boot, the module loads in a "not compiled" state: every
# function raises AluniCore::NotCompiled with the command to run, and the
# Ruby services turn that into a Failure(code: :core_error).
module AluniCore
  class Error < StandardError; end

  class NotCompiled < Error
    def initialize(msg = "aluni_core is not compiled; run `bin/rails core:compile`")
      super
    end
  end

  FUNCTIONS = %i[normalize].freeze

  begin
    require "aluni_core/aluni_core"
    COMPILED = true
  rescue LoadError => e
    COMPILED = false
    warn "[aluni_core] native extension not loaded (#{e.message.lines.first&.strip}); run `bin/rails core:compile`"
    FUNCTIONS.each do |name|
      define_singleton_method(name) { |*_args| raise NotCompiled }
    end
  end

  def self.compiled? = COMPILED
end
