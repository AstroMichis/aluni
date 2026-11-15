require "rails_helper"

RSpec.describe "Staff services" do
  let(:data) { Fields::Farm.sample_data }

  it "adds a member with valid fields only and refuses a bad role or name" do
    result = Staff::SaveMemberService.call(data: data, name: "Rosa", role: "viewer", fields: %w[north nowhere])
    expect(result.value["team"].last).to eq("id" => "m3", "name" => "Rosa", "role" => "viewer", "fields" => %w[north])

    expect(Staff::SaveMemberService.call(data: data, name: "Rosa", role: "boss")).to be_failure
    expect(Staff::SaveMemberService.call(data: data, name: " ", role: "worker")).to be_failure
  end

  it "unassigns a removed member's tasks" do
    data2 = Staff::RemoveMemberService.call(data: data, id: "m2").value
    expect(data2["team"].map { |m| m["id"] }).to eq(%w[m1])
    expect(data2["tasks"].find { |t| t["id"] == "t1" }["member"]).to be_nil
  end

  it "adds, completes and removes tasks, checking fields, people and dates" do
    data2 = Staff::SaveTaskService.call(data: data, title: "Fence", field: "creek", member: "m1", due: "2025-12-01").value
    expect(data2["tasks"].last).to include("id" => "t4", "done" => false)
    expect(Staff::SaveTaskService.call(data: data2, id: "t4", done: "true").value["tasks"].last["done"]).to be(true)
    expect(Staff::RemoveTaskService.call(data: data2, id: "t4").value["tasks"].size).to eq(3)

    expect(Staff::SaveTaskService.call(data: data, title: "Fence", due: "soon")).to be_failure
    expect(Staff::SaveTaskService.call(data: data, title: "Fence", member: "m9")).to be_failure
  end

  it "keeps roles' capabilities in one place" do
    expect(Staff::Roles.can?("owner", "invite")).to be(true)
    expect(Staff::Roles.can?("worker", "edit_data")).to be(false)
  end
end
