require "rails_helper"

RSpec.describe "Native shell endpoints", type: :request do
  describe "GET /configurations/v1/:platform" do
    it "serves tabs, chrome and path rules per platform" do
      get "/configurations/v1/ios"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.dig("settings", "brand", "name")).to eq("Aluni")
      expect(json.dig("settings", "brand", "sign_in_path")).to eq("/en/sign_in")
      expect(json.dig("settings", "tabs").map { |t| t["title"] }).to eq([ "Home", "Account" ])
      expect(json.dig("settings", "tabs").first["icon"]).to eq("house")
      expect(json["rules"].find { |r| r["properties"]["presentation"] == "replace" }["patterns"].first).to include("sign_in")

      get "/configurations/v1/android", headers: { "HTTP_ACCEPT_LANGUAGE" => "es" }
      expect(response.parsed_body.dig("settings", "tabs").first).to include("title" => "Inicio", "icon" => "ic_home", "url" => "/es/app")
    end

    it "knows only ios and android" do
      get "/configurations/v1/windows"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "app links" do
    it "answers 404 until the store credentials exist" do
      get "/.well-known/apple-app-site-association"
      expect(response).to have_http_status(:not_found)
      get "/.well-known/assetlinks.json"
      expect(response).to have_http_status(:not_found)
    end

    it "serves the association files, with the passkey relations, once credentials exist" do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:native_app, :apple_team_id).and_return("TEAM123")
      allow(Rails.application.credentials).to receive(:dig).with(:native_app, :android_cert_sha256).and_return("AA:BB")

      get "/.well-known/apple-app-site-association"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.dig("applinks", "details", 0, "appIDs")).to eq([ "TEAM123.us.aluni.app" ])
      expect(json.dig("applinks", "details", 0, "components")).to include("/" => "/app/*")
      expect(json.dig("webcredentials", "apps")).to eq([ "TEAM123.us.aluni.app" ])

      get "/.well-known/assetlinks.json"
      expect(response).to have_http_status(:ok)
      entry = response.parsed_body.first
      expect(entry["relation"]).to include("delegate_permission/common.get_login_creds")
      expect(entry.dig("target", "package_name")).to eq("us.aluni.app")
      expect(entry.dig("target", "sha256_cert_fingerprints")).to eq([ "AA:BB" ])
    end
  end
end
