require "rails_helper"

RSpec.describe Onboarding::Redactor do
  it "replaces emails" do
    expect(described_class.redact("write to ana.perez+farm@example.co.cr please")).to eq("write to [email] please")
  end

  it "replaces phone-shaped digit groups with any common separator" do
    expect(described_class.redact("call me at 555-123-4567 or (506) 8888 9999")).to eq("call me at [phone] or [phone]")
    expect(described_class.redact("+1 515 555 0199")).to eq("[phone]")
    expect(described_class.redact("my number is 555.123.4567")).to eq("my number is [phone]")
  end

  it "leaves decimals, coordinates, years and small numbers alone" do
    expect(described_class.redact("42.0123, -93.75")).to eq("42.0123, -93.75")
    expect(described_class.redact("9.934567 -84.123456")).to eq("9.934567 -84.123456")
    expect(described_class.redact("ph 6.5 and 12.5 hectares, 3 fields")).to eq("ph 6.5 and 12.5 hectares, 3 fields")
    expect(described_class.redact("in 2024 I planted corn after 2023 beans")).to eq("in 2024 I planted corn after 2023 beans")
  end

  it "redacts a phone that sits beside a coordinate without touching the coordinate" do
    expect(described_class.redact("42.0123 555-123-4567")).to eq("42.0123 [phone]")
  end

  it "strips tags, tidies whitespace and caps the length" do
    expect(described_class.redact("<b>hi</b> <img src=x onerror=alert(1)> there")).to eq("hi there")
    expect(described_class.redact("hello    there\n\n\n  friend ")).to eq("hello there\nfriend")
    expect(described_class.redact("a" * 3000).length).to eq(described_class::MAX_LENGTH)
    expect(described_class.redact(nil)).to eq("")
  end
end
