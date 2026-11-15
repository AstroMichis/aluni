require "rails_helper"

RSpec.describe Auth::LinkToken do
  let(:record) { create(:sign_in_code) }

  it "round-trips the row id and the code, and rejects tampering and age" do
    token = described_class.generate(record, "123456")

    expect(described_class.read(token)).to eq("id" => record.id, "code" => "123456")
    expect(described_class.read(token + "x")).to be_nil
    expect(described_class.read("")).to be_nil

    travel SignInCode::TTL + 1.second
    expect(described_class.read(token)).to be_nil
  end
end
