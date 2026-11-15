require "rails_helper"

RSpec.describe Fields::FetchSoilMoistureJob do
  let(:user) { create(:user) }
  let(:farm) { create(:farm, user: user) }
  let(:field) { create(:field, farm: farm, latitude: -33.5975, longitude: -70.7) }
  let(:client) { instance_double(Appeears::Client) }
  let(:csv) do
    "ID,Category,Latitude,Longitude,Date,SPL4SMGP_008_Geophysical_Data_sm_rootzone,SPL4SMGP_008_Geophysical_Data_sm_rootzone_pctl\n" \
      "field-1,,-33.5975,-70.7,2026-01-01T01:30:00,0.12,10.0\n"
  end

  before do
    allow(Appeears::Client).to receive_messages(configured?: true, new: client)
  end

  it "submits the task, keeps the observation pending and checks back later" do
    allow(client).to receive(:submit_point).and_return("task-1")

    expect { described_class.perform_now(field.id) }
      .to have_enqueued_job(described_class).with(field.id, task_id: "task-1", polls: 1)
    expect(field.observation("smap")).to have_attributes(status: "pending", payload: { "task_id" => "task-1" })
    expect(client).to have_received(:submit_point).with(hash_including(layers: described_class::LAYERS, id: "field-#{field.id}"))
  end

  it "reads the results when the task is done" do
    create(:field_observation, field: field, source: "smap", status: :pending, payload: { "task_id" => "task-1" })
    allow(client).to receive_messages(status: "done", results_csv: csv)

    described_class.perform_now(field.id, task_id: "task-1", polls: 2)

    smap = field.reload.observation("smap")
    expect(smap).to be_ok
    expect(smap.payload).to include("latest" => { "date" => "2026-01-01", "rootzone" => 0.12, "pctl" => 10 }, "dry_months" => [ "2026-01" ])
  end

  it "polls again while AppEEARS works, and gives up after the last check" do
    create(:field_observation, field: field, source: "smap", status: :pending, payload: { "task_id" => "task-1" })
    allow(client).to receive(:status).and_return("processing")

    expect { described_class.perform_now(field.id, task_id: "task-1", polls: 3) }
      .to have_enqueued_job(described_class).with(field.id, task_id: "task-1", polls: 4)

    described_class.perform_now(field.id, task_id: "task-1", polls: described_class::MAX_POLLS)
    expect(field.reload.observation("smap")).to be_failed
  end

  it "ignores a task a newer request replaced, and records errors and missing credentials" do
    create(:field_observation, field: field, source: "smap", status: :pending, payload: { "task_id" => "newer" })
    allow(client).to receive(:status)
    described_class.perform_now(field.id, task_id: "task-1", polls: 2)
    expect(client).not_to have_received(:status)

    allow(client).to receive(:submit_point).and_raise(DataSources::Client::Error, "Appeears::Client: login failed (401)")
    described_class.perform_now(field.id)
    expect(field.reload.observation("smap")).to have_attributes(status: "failed", error: /login failed/)

    allow(Appeears::Client).to receive(:configured?).and_return(false)
    described_class.perform_now(field.id)
    expect(field.reload.observation("smap")).to be_empty
  end
end
