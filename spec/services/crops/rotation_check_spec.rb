require "rails_helper"

RSpec.describe Crops::RotationCheck do
  def findings(*crops) = described_class.new(crops.each_with_index.map { |crop, i| [ (2020 + i).to_s, crop ] }).findings.map(&:kind)

  it "flags the same family twice, the same crop three times, and four seasons without a legume" do
    expect(findings("corn", "soybeans", "corn", "soybeans")).to be_empty
    expect(findings("soybeans", "beans")).to eq(%w[same_family])
    expect(findings("corn", "corn", "corn")).to eq(%w[same_family same_family monoculture])
    expect(findings("corn", "wheat", "potato", "oats")).to include("no_legume")
    expect(findings("vegetables", "vegetables")).to be_empty # many families: no rule
  end
end
