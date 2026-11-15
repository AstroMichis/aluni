require "rails_helper"

RSpec.describe SignInCodes::PurgeJob, type: :job do
  it "deletes codes older than a day and keeps the rest" do
    old = create(:sign_in_code, created_at: 2.days.ago)
    fresh = create(:sign_in_code, destination: "b@example.com")

    described_class.perform_now

    expect(SignInCode.exists?(old.id)).to be(false)
    expect(SignInCode.exists?(fresh.id)).to be(true)
  end
end
