require "rails_helper"

RSpec.describe Auth::CreateAccountService do
  let(:field) { { "latitude" => 42.0, "longitude" => -93.75, "place_label" => "Near Ames", "country_code" => "US", "admin_area" => "Iowa", "location_source" => "map", "crop_name" => "Corn", "irrigation" => "rainfed", "area" => 12.0, "area_unit" => "acres" } }
  let(:record) { create(:sign_in_code, :verified, destination: "ana@example.com", locale: "en", pending: { "display_name" => "Ana", "locale" => "es", "field" => field }) }

  it "creates the account with the parked name, locale and field, and completes the setup" do
    result = described_class.call(sign_in_code: record, display_name: "", ip: "1.1.1.1")

    expect(result).to be_success
    user = result.value[:user]
    expect(user.display_name).to eq("Ana")
    expect(user.email_address).to eq("ana@example.com")
    expect(user.locale).to eq("es")
    expect(user.email_verified_at).to be_present
    expect(user.farms.first.fields.first.latitude).to eq(42.0)
    expect(user.farms.first.fields.first.field_crops.first.scientific_name).to eq("Zea mays")
    expect(user.onboarding_complete?).to be(true)
    expect(record.reload).to be_used
  end

  it "prefers a name typed now and needs one somewhere" do
    expect(described_class.call(sign_in_code: record, display_name: "Ana Maria", ip: "1.1.1.1").value[:user].display_name).to eq("Ana Maria")

    bare = create(:sign_in_code, :verified, destination: "b@example.com")
    expect(described_class.call(sign_in_code: bare, display_name: " ", ip: "1.1.1.1").error).to include(code: :name_required)
  end

  it "refuses an unproven, stale or already used code, and closed sign-ups" do
    expect(described_class.call(sign_in_code: create(:sign_in_code), display_name: "Ana", ip: "1.1.1.1").error).to include(code: :expired)

    used = create(:sign_in_code, :verified, destination: "c@example.com", used_at: Time.current)
    expect(described_class.call(sign_in_code: used, display_name: "Ana", ip: "1.1.1.1").error).to include(code: :expired)

    stale = create(:sign_in_code, :verified, destination: "d@example.com", verified_at: 11.minutes.ago)
    expect(described_class.call(sign_in_code: stale, display_name: "Ana", ip: "1.1.1.1").error).to include(code: :expired)

    Rails.configuration.x.signups.enabled = false
    expect(described_class.call(sign_in_code: record, display_name: "Ana", ip: "1.1.1.1").error).to include(code: :signups_closed)
  ensure
    Rails.configuration.x.signups.enabled = true
  end

  it "returns the existing account when one appeared for the address meanwhile" do
    user = create(:user, :with_email, email_address: "ana@example.com")

    result = described_class.call(sign_in_code: record, display_name: "Ana", ip: "1.1.1.1")

    expect(result.value).to include(user: user, created: false)
  end
end
