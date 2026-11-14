require "rails_helper"

RSpec.describe Passkey, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:public_key) }

  it "has a unique external id" do
    existing = create(:passkey)
    expect(build(:passkey, external_id: existing.external_id)).not_to be_valid
  end

  it "records usage" do
    passkey = create(:passkey)
    freeze_time do
      passkey.touch_usage!(7)
      expect(passkey.reload).to have_attributes(sign_count: 7, last_used_at: Time.current)
    end
  end
end
