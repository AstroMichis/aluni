require "rails_helper"

RSpec.describe Core::NormalizeService do
  it "normalizes through the Rust extension" do
    result = described_class.call(input: "  Hello   World ")

    expect(result).to be_success
    expect(result.value).to eq("hello world")
  end

  it "turns the extension's ArgumentError into a core_error Failure" do
    result = described_class.call(input: "   ")

    expect(result).to be_failure
    expect(result.error).to include(code: :core_error, message: "input is empty")
  end

  it "accepts anything that answers to_s" do
    expect(described_class.call(input: :Symbol).value).to eq("symbol")
  end
end
