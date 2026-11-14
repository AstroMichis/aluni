require "rails_helper"

RSpec.describe Sessions::PurgeStaleJob do
  it "deletes sessions unused for a year and keeps the rest" do
    user = create(:user)
    stale = create(:session, user: user)
    stale.update_column(:updated_at, 13.months.ago)
    fresh = create(:session, user: user)

    described_class.perform_now

    expect(Session.where(id: stale.id)).not_to exist
    expect(Session.where(id: fresh.id)).to exist
  end

  it "is scheduled on a queue Sidekiq consumes" do
    schedule = YAML.load_file(Rails.root.join("config/sidekiq_cron.yml"))
    queues = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/sidekiq.yml"))).result, permitted_classes: [ Symbol ])[:queues].map(&:first)
    entry = schedule.fetch("sessions_purge_stale")

    expect(entry["class"]).to eq(described_class.name)
    expect(queues).to include(entry["queue"])
    expect(Platform::CronControl.cron_job?(described_class.name)).to be(true)
  end
end
