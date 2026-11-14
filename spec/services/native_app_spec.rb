require "rails_helper"

RSpec.describe NativeApp do
  it "has no store urls until the apps are published" do
    expect(NativeApp.app_store_url).to be_nil
    expect(NativeApp.play_store_url).to be_nil
  end

  it "reads configured store urls and treats blanks as missing" do
    configured = NativeApp.config.merge("store" => { "app_store_url" => "https://apps.apple.com/app/id1", "play_store_url" => "" })
    allow(NativeApp).to receive(:config).and_return(configured)

    expect(NativeApp.app_store_url).to eq("https://apps.apple.com/app/id1")
    expect(NativeApp.play_store_url).to be_nil
  end

  it "serves the brand colours the shells read before sign-in" do
    expect(NativeApp.colors).to include("tint" => "#B69A5B", "background" => "#0F2920")
  end
end
