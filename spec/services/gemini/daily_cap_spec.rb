require "rails_helper"

RSpec.describe Gemini::DailyCap do
  let(:now) { Time.utc(2026, 11, 15, 12) }

  around do |example|
    config = Rails.configuration.x.gemini
    previous = config.daily_cap
    config.daily_cap = 3
    REDIS.del(described_class.key(now))
    example.run
  ensure
    config.daily_cap = previous
    REDIS.del(described_class.key(now))
  end

  it "does nothing when the cap is off" do
    Rails.configuration.x.gemini.daily_cap = 0

    5.times { expect(described_class.count!(now: now)).to be_nil }
    expect(described_class.calls_today(now: now)).to eq(0)
  end

  it "lets requests through up to the limit" do
    3.times { described_class.count!(now: now) }

    expect(described_class.calls_today(now: now)).to eq(3)
    expect(Platform::Switchboard.paused?(:gemini)).to be(false)
  end

  it "pauses the gemini switch once, on the first request over the limit, and refuses the rest" do
    3.times { described_class.count!(now: now) }

    expect { described_class.count!(now: now) }.to raise_error(Platform::ServicePaused)
    expect { described_class.count!(now: now) }.to raise_error(Platform::ServicePaused)

    switch = PlatformSwitch.find_by!(service: "gemini")
    expect(switch).to have_attributes(paused: true, reason: "daily_cap", paused_by: "daily_cap")
  end

  it "gives a fresh budget when an operator resumes gemini" do
    4.times { described_class.count!(now: now) rescue Platform::ServicePaused }

    travel_to(now) { Platform::ToggleService.call(service: "gemini", paused: false) }

    expect(described_class.calls_today(now: now)).to eq(0)
    expect { described_class.count!(now: now) }.not_to raise_error
  end

  it "keeps one counter per UTC day" do
    3.times { described_class.count!(now: now) }

    expect { described_class.count!(now: now + 1.day) }.not_to raise_error
  ensure
    REDIS.del(described_class.key(now + 1.day))
  end

  it "fails open when Redis is unavailable" do
    broken = instance_double(Redis)
    allow(broken).to receive(:incr).and_raise(Redis::CannotConnectError)

    5.times { expect(described_class.count!(redis: broken, now: now)).to be_nil }
  end

  it "is checked by the client before each request" do
    allow(described_class).to receive(:count!).and_raise(Platform::ServicePaused.new(:gemini))
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:gemini, :api_key).and_return("test-key")

    expect { Gemini::Client.new(model: :flash).generate("hi") }.to raise_error(Platform::ServicePaused)
    expect(a_request(:post, /generateContent/)).not_to have_been_made
  end
end
