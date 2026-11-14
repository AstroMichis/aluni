require "rails_helper"

RSpec.describe Result do
  describe Result::Success do
    subject(:result) { Result::Success.new(42) }

    it { expect(result).to be_success }
    it { expect(result).not_to be_failure }
    it { expect(result.value).to eq(42) }
    it { expect(result.data).to eq(42) }
    it { expect(result.error).to be_nil }
    it { expect(result.fmap { |v| v + 1 }.value).to eq(43) }
    it { expect(result.bind { |v| Result::Failure.new(v) }).to be_failure }
    it { expect(result.value_or(0)).to eq(42) }
    it { expect(result).to be_frozen }

    it "pattern matches positionally and by key" do
      case result
      in Result::Success(value) then expect(value).to eq(42)
      end
      case result
      in { value: } then expect(value).to eq(42)
      end
    end
  end

  describe Result::Failure do
    subject(:result) { Result::Failure.new(code: :nope, message: "No") }

    it { expect(result).to be_failure }
    it { expect(result.value).to be_nil }
    it { expect(result.error).to eq(code: :nope, message: "No") }
    it { expect(result.fmap { |v| v + 1 }).to equal(result) }
    it { expect(result.value_or("default")).to eq("default") }
    it { expect(result.or_else { |e| e[:code] }).to eq(:nope) }

    it "exposes the error hash keys when pattern matching" do
      case result
      in { code:, message: } then expect([ code, message ]).to eq([ :nope, "No" ])
      end
    end
  end

  describe Result::Mixin do
    let(:host) { Class.new { include Result::Mixin; public :Success, :Failure }.new }

    it "builds a Success" do
      expect(host.Success(1)).to satisfy { |r| r.success? && r.value == 1 }
    end

    it "merges keyword arguments into the error hash" do
      expect(host.Failure(code: :bad, message: "x").error).to eq(code: :bad, message: "x")
      expect(host.Failure({ code: :bad }, message: "x").error).to eq(code: :bad, message: "x")
      expect(host.Failure("plain").error).to eq("plain")
    end
  end
end
