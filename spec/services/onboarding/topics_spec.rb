require "rails_helper"

RSpec.describe Onboarding::Topics do
  it "lists the topics in conversation order, welcome first" do
    expect(described_class.keys).to eq(%w[welcome crops soil goals summary])
    expect(described_class.first).to eq("welcome")
    expect(described_class.size).to eq(5)
    expect(described_class.include?("soil")).to be(true)
    expect(described_class.include?("location")).to be(false)
  end

  it "walks forward and stops after the last topic" do
    expect(described_class.next("welcome")).to eq("crops")
    expect(described_class.next("summary")).to be_nil
    expect(described_class.next("nope")).to be_nil
    expect(described_class.index("crops")).to eq(1)
    expect(described_class.index("nope")).to be_nil
  end

  it "exposes guidance, required facts, rules and title keys" do
    expect(described_class.guidance("welcome")).to include("field basics you already know")
    expect(described_class.guidance("crops")).to include("history")
    expect(described_class.required("welcome")).to eq([])
    expect(described_class.required("crops")).to eq(%w[crops])
    expect(described_class.required("summary")).to eq([])
    expect(described_class.rules).to include("One question per turn").and include("settled during setup")
    expect(described_class.title_key("soil")).to eq("onboarding.topics.soil")
    expect { described_class.guidance("nope") }.to raise_error(ArgumentError, /unknown onboarding topic/)
  end

  it "has a title, a transition and a continuation list for every topic in both locales" do
    I18n.available_locales.each do |locale|
      described_class.keys.each do |key|
        expect(I18n.t(described_class.title_key(key), locale: locale)).to be_present
        expect(I18n.t("onboarding.transitions.#{key}", locale: locale)).to be_present
        expect(I18n.t("onboarding.continuations.#{key}", locale: locale)).to be_an(Array).and be_present
      end
    end
  end

  describe ".validate!" do
    after { described_class.reload! }

    def load_yaml(data)
      described_class.reload!
      allow(YAML).to receive(:safe_load_file).with(described_class::PATH, aliases: false).and_return(data)
    end

    it "passes for the shipped file" do
      expect(described_class.validate!).to be(true)
    end

    it "raises on a required fact the snapshot cannot read" do
      load_yaml("rules" => "- be kind", "topics" => [ { "key" => "welcome", "required" => [ "weather.today" ], "guidance" => "hi" } ])

      expect { described_class.validate! }.to raise_error(Onboarding::Topics::Invalid, /weather\.today/)
    end

    it "raises on a duplicate topic or a topic without guidance" do
      load_yaml("rules" => "- be kind", "topics" => [ { "key" => "a", "guidance" => "x" }, { "key" => "a", "guidance" => "y" } ])
      expect { described_class.validate! }.to raise_error(Onboarding::Topics::Invalid, /duplicate/)

      load_yaml("rules" => "- be kind", "topics" => [ { "key" => "a" } ])
      expect { described_class.validate! }.to raise_error(Onboarding::Topics::Invalid, /no guidance/)
    end
  end
end
