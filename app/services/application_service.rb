# frozen_string_literal: true

# Base class for service objects: one service, one action, named <Verb>Service,
# keyword arguments in initialize, a Result from #call. `step` unwraps a Success
# or halts the whole call with the Failure; `try_external` turns listed
# exceptions from an outside call into a Failure(code: :external_error).
class ApplicationService
  include Result::Mixin

  def self.call(...)
    catch(:halt) { new(...).call }
  end

  private_class_method :new

  private

  def step(result)
    case result
    when Result::Success then result.value
    when Result::Failure then throw(:halt, result)
    else result
    end
  end

  def try_external(*exceptions, &block)
    value = block.call
    Success(value)
  rescue *exceptions => e
    Rails.logger.error("[#{self.class.name}] External call failed: #{e.message}")
    Failure(code: :external_error, message: e.message)
  end
end
