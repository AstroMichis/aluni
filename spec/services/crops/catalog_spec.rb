require "rails_helper"

RSpec.describe Crops::Catalog, type: :service do
  it "finds a crop by any alias, without accents or case, named in the locale" do
    expect(described_class.find("maíz", locale: :es)).to eq(key: "maize", crop_name: "Maíz", scientific_name: "Zea mays")
    expect(described_class.find("ELOTE", locale: :en)).to include(key: "maize", crop_name: "Corn")
    expect(described_class.find("papa criolla", locale: :en)).to include(key: "potato", scientific_name: "Solanum tuberosum")
    expect(described_class.find("platano", locale: :es)).to include(key: "plantain", crop_name: "Plátano")
    expect(described_class.find("rocket fuel", locale: :en)).to be_nil
    expect(described_class.find("", locale: :en)).to be_nil
  end

  it "searches by prefix first, then by a word, each crop once, up to the limit" do
    keys = described_class.search("ma", locale: :en, limit: 20).map { |c| c[:key] }

    expect(keys).to include("maize", "mango", "cassava", "peanut", "apple", "plantain")
    # "plátano macho" matches on a word, so plantain comes after every name that starts with "ma".
    expect(keys.index("plantain")).to be > keys.index("maize")
    expect(keys.index("plantain")).to be > keys.index("apple")
    expect(keys.uniq).to eq(keys)
    expect(described_class.search("ma", locale: :en, limit: 3).size).to eq(3)
    expect(described_class.search("ma", locale: :en).size).to eq(described_class::DEFAULT_LIMIT)
    expect(described_class.search("  ", locale: :en)).to eq([])
  end

  it "lists every crop sorted by its name in the locale" do
    en = described_class.all(locale: :en)
    es = described_class.all(locale: :es)

    expect(en.size).to be >= 60
    expect(en.map { |c| c[:crop_name] }).to eq(en.map { |c| c[:crop_name] }.sort_by { |n| described_class.fold(n) })
    expect(es.find { |c| c[:key] == "beans" }).to eq(key: "beans", crop_name: "Frijol", scientific_name: "Phaseolus vulgaris")
    expect(en.map { |c| c[:scientific_name] }).to all(be_present)
  end
end
