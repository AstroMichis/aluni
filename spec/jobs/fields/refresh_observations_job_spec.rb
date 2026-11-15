require "rails_helper"

RSpec.describe Fields::RefreshObservationsJob do
  let(:user) { create(:user) }
  let(:farm) { create(:farm, user: user) }

  def field_with_power(fetched_at)
    field = create(:field, farm: farm)
    create(:field_observation, field: field, source: "nasa_power", fetched_at: fetched_at)
    field
  end

  it "refreshes the quick sources of fields fetched over a week ago, spread out" do
    stale = field_with_power(8.days.ago)
    other = field_with_power(10.days.ago)
    field_with_power(1.day.ago)
    create(:field, :unlocated, farm: farm)

    freeze_time do
      expect { described_class.perform_now("weekly") }
        .to have_enqueued_job(Fields::FetchObservationsJob).with(stale.id, only: %w[nasa_power vegetation]).at(Time.current)
        .and have_enqueued_job(Fields::FetchObservationsJob).with(other.id, only: %w[nasa_power vegetation]).at(3.minutes.from_now)
        .and have_enqueued_job(Fields::FetchObservationsJob).exactly(2).times # not the fresh field nor the one without a pin
    end
  end

  it "asks for everything once a month, only where the oldest data is a month old" do
    old = field_with_power(1.day.ago)
    create(:field_observation, field: old, source: "gaez", fetched_at: 40.days.ago)
    field_with_power(2.days.ago)

    expect { described_class.perform_now("monthly") }.to have_enqueued_job(Fields::FetchObservationsJob).with(old.id).exactly(:once)
  end

  it "runs only the quick sources when asked to" do
    stub_all_data_sources(us: false)
    field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)

    Fields::FetchObservationsJob.perform_now(field.id, only: %w[nasa_power vegetation gaez])

    expect(field.observations.pluck(:source)).to contain_exactly("nasa_power", "vegetation") # gaez is not a quick source
  end
end
