# frozen_string_literal: true

module Core
  # The seam where Rust plugs in: an ordinary service object is the public API,
  # AluniCore (vendor/gems/aluni_core) does the work. Callers never see the
  # extension; magnus raises Ruby exceptions at the boundary, caught here.
  class NormalizeService < ApplicationService
    def initialize(input:)
      @input = input
    end

    def call
      value = step normalize
      Success(value)
    end

    private

    def normalize
      Success(AluniCore.normalize(@input.to_s))
    rescue ArgumentError, RuntimeError, AluniCore::Error => e
      Rails.logger.error("[#{self.class.name}] core failure: #{e.class}: #{e.message}")
      Failure(code: :core_error, message: e.message)
    end
  end
end
