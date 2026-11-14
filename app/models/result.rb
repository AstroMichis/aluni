# frozen_string_literal: true

# Value objects returned by every service (app/services). Controllers pattern
# match on them:
#
#   case Some::Service.call(...)
#   in Result::Success(record) then redirect_to record
#   in Result::Failure(error)  then render ..., status: :unprocessable_content
#   end
module Result
  class Success
    attr_reader :value
    alias data value

    def initialize(value = nil)
      @value = value
      freeze
    end

    def success? = true
    def failure? = false
    def error = nil

    def bind(&block)
      block.call(@value)
    end
    alias and_then bind

    def fmap(&block)
      self.class.new(block.call(@value))
    end

    def or_else = self

    def tee
      yield @value
      self
    end

    def value_or(_default = nil) = @value

    # Pattern matching: case result; in Result::Success(val)
    def deconstruct = [ @value ]

    def deconstruct_keys(_keys)
      { value: @value, data: @value }
    end
  end

  class Failure
    attr_reader :error

    def initialize(error = nil)
      @error = error
      freeze
    end

    def success? = false
    def failure? = true
    def value = nil
    def data = nil

    def bind = self
    alias and_then bind

    def fmap = self

    def or_else
      yield @error
    end

    def tee = self

    def value_or(default = nil)
      block_given? ? yield(@error) : default
    end

    # Pattern matching: case result; in Result::Failure(err)
    def deconstruct = [ @error ]

    def deconstruct_keys(_keys)
      if @error.is_a?(Hash)
        @error.merge(error: @error)
      else
        { error: @error }
      end
    end
  end

  # Private constructors for services and specs: Success(value), Failure(code:, message:).
  module Mixin
    private

    def Success(value = nil)
      Result::Success.new(value)
    end

    def Failure(error = nil, **kwargs)
      if kwargs.any?
        Result::Failure.new(error.is_a?(Hash) ? error.merge(kwargs) : kwargs)
      else
        Result::Failure.new(error)
      end
    end
  end
end
