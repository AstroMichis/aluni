require "rails_helper"

RSpec.describe Fields::CellLayout do
  it "gives each crop its share of the 100 cells, by the largest remainder" do
    expect(described_class.allocate([ 0.334, 0.333, 0.333 ]).map(&:size)).to eq([ 34, 33, 33 ])
    expect(described_class.allocate([ 0.25 ]).map(&:size)).to eq([ 25 ])
  end

  it "lays a fresh split as vertical bands, left to right" do
    left, right = described_class.allocate([ 0.5, 0.5 ])
    expect(left.map { |c| c % 10 }.uniq.sort).to eq([ 0, 1, 2, 3, 4 ])
    expect(right.map { |c| c % 10 }.uniq.sort).to eq([ 5, 6, 7, 8, 9 ])
  end

  it "keeps the cells a crop had and grows next to them" do
    corner = [ 0, 1, 10, 11 ]
    grown = described_class.allocate([ 0.06 ], [ corner ]).first
    expect(grown).to include(*corner)
    expect(grown.size).to eq(6)
    expect(grown - corner).to all(satisfy { |c| corner.any? { |k| (c - k).abs == 1 || (c - k).abs == 10 } })
  end

  it "never gives one cell to two crops" do
    cells = described_class.allocate([ 0.4, 0.4, 0.2 ], [ (0...50).to_a, (40...90).to_a ])
    expect(cells.flatten.uniq.size).to eq(cells.flatten.size)
  end
end
