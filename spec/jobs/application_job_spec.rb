require "rails_helper"

class SwitchboardProbeJob < ApplicationJob
  queue_as :gemini

  cattr_accessor :runs, default: 0

  def perform(explode: false)
    raise Platform::ServicePaused.new(:gemini) if explode

    self.class.runs += 1
  end
end

RSpec.describe ApplicationJob do
  before { SwitchboardProbeJob.runs = 0 }

  it "runs the job when nothing is paused" do
    SwitchboardProbeJob.perform_now

    expect(SwitchboardProbeJob.runs).to eq(1)
  end

  it "holds a job whose queue's service is paused and retries later" do
    create(:platform_switch, service: "gemini", paused: true)

    expect { SwitchboardProbeJob.perform_now }.to have_enqueued_job(SwitchboardProbeJob)
    expect(SwitchboardProbeJob.runs).to eq(0)
  end

  it "holds every job while jobs are paused" do
    create(:platform_switch, service: "jobs", paused: true)

    expect { SwitchboardProbeJob.perform_now }.to have_enqueued_job(SwitchboardProbeJob)
    expect(SwitchboardProbeJob.runs).to eq(0)
  end

  it "drops a cron job instead of retrying it" do
    allow(Platform::CronControl).to receive(:cron_job?).with("SwitchboardProbeJob").and_return(true)
    create(:platform_switch, service: "cron", paused: true)

    expect { SwitchboardProbeJob.perform_now }.not_to have_enqueued_job
    expect(SwitchboardProbeJob.runs).to eq(0)
  end

  it "holds a job whose client refused the call because the service was paused" do
    expect { SwitchboardProbeJob.perform_now(explode: true) }.to have_enqueued_job(SwitchboardProbeJob)
  end
end
