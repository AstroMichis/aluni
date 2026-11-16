require "rails_helper"

RSpec.describe Erosion::Rusle do
  # The Ames pin of the hindcast: SSURGO Clarion loam (kwfact .24, USLE slope length 40 m, T 5 t/acre), 3DEP slope 4.05 %.
  subject(:rusle) { described_class.new(k: 0.24, slope: 4.05, slope_length: 40, tolerable: 5 * described_class::T_SI, monthly_mm: ames_imerg_months) }

  let(:strategies) do
    { "current" => %w[glycine-max zea-mays glycine-max], "small_grain" => %w[triticum-aestivum glycine-max zea-mays],
      "other_family" => %w[helianthus-annuus zea-mays helianthus-annuus] }
  end

  it "orders the rotations as docs/proposal V6 does, all above the tolerable loss" do
    losses = strategies.transform_values { |crops| rusle.loss(crops) }

    expect(losses.sort_by { |_, l| l.no_cover }.map(&:first)).to eq(%w[small_grain current other_family])
    expect(losses.values).to all(be_over_tolerable)
    expect(losses.values.map(&:saved_pct)).to all(be_between(8, 18))
    expect(rusle.ls_factor.round(2)).to eq(0.58)
  end

  it "has no loss for a crop without an FAO-56 curve" do
    expect(rusle.loss(%w[medicago-sativa zea-mays medicago-sativa])).to be_nil
  end

  it "needs the soil survey: nothing outside the US" do
    field = create(:field)
    expect(described_class.for(field, slope: 4.0)).to be_nil
  end
end
