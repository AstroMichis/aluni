require "rails_helper"

RSpec.describe ApplicationService do
  let(:service_class) do
    Class.new(ApplicationService) do
      def initialize(value:, fail_at: nil)
        @value = value
        @fail_at = fail_at
      end

      def call
        first = step Success(@value)
        step Failure(code: :boom, message: "halted") if @fail_at == :step
        doubled = step try_external(ArgumentError) {
          raise ArgumentError, "outside said no" if @fail_at == :external
          first * 2
        }
        Success(doubled)
      end
    end
  end

  it "returns a Success from a happy path" do
    result = service_class.call(value: 2)
    expect(result).to be_success
    expect(result.value).to eq(4)
  end

  it "halts the call at the first failing step" do
    result = service_class.call(value: 2, fail_at: :step)
    expect(result).to be_failure
    expect(result.error).to include(code: :boom)
  end

  it "turns a listed exception from an outside call into an external_error Failure" do
    result = service_class.call(value: 2, fail_at: :external)
    expect(result).to be_failure
    expect(result.error).to include(code: :external_error, message: "outside said no")
  end

  it "cannot be instantiated directly" do
    expect { service_class.new(value: 1) }.to raise_error(NoMethodError)
  end
end
