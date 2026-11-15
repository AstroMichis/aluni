require "rails_helper"

# The finder's two Turbo Frames. The geocoder is doubled at the class boundary;
# spec/services/geocoding/client_spec.rb covers the HTTP.
RSpec.describe "Places", type: :request do
  let(:ames) do
    { label: "Ames, Story County, Iowa, United States", display: "Ames, Iowa", latitude: 42.030781, longitude: -93.631913,
      country_code: "US", country: "United States", admin_area: "Iowa" }
  end
  let(:client) { instance_double(Geocoding::Client, search: [ ames ], reverse: ames, last_error: nil) }

  before { allow(Geocoding::Client).to receive(:new).and_return(client) }

  describe "GET /places" do
    it "answers the place-results frame with an accessible listbox the finder reads" do
      get places_path(locale: "en", q: "Ames, Iowa")

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/\A<turbo-frame[^>]*id="place-results"/)
      expect(response.body).to include('role="listbox"').and include('role="option"').and include('data-action="finder#pickPlace"')
      expect(response.body).to include('data-latitude="42.030781"').and include('data-longitude="-93.631913"')
      expect(response.body).to include('data-label="Ames, Iowa"').and include('data-country-code="US"').and include('data-admin-area="Iowa"')
      expect(response.body).to include("Ames, Story County, Iowa, United States")
      expect(response.body).not_to include("<html")
      expect(client).to have_received(:search).with("Ames, Iowa", locale: :en)
    end

    it "searches in Spanish under /es" do
      get places_path(locale: "es", q: "Bogotá")

      expect(client).to have_received(:search).with("Bogotá", locale: :es)
      expect(response.body).to include(I18n.t("places.index.results_label", locale: :es))
    end

    it "shows a hint for a blank query without calling the geocoder" do
      get places_path(locale: "en", q: "  ")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("places.index.hint"))
      expect(client).not_to have_received(:search)
    end

    it "says when nothing was found" do
      allow(client).to receive(:search).and_return([])

      get places_path(locale: "en", q: "Zzzz")

      expect(response.body).to include(ERB::Util.html_escape(I18n.t("places.index.empty", query: "Zzzz")))
    end

    it "keeps calm in the same frame when the geocoder fails or is paused" do
      allow(client).to receive_messages(search: nil, last_error: { type: :paused })

      get places_path(locale: "en", q: "Ames")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="place-results"').and include(I18n.t("places.unavailable"))
    end
  end

  describe "GET /places/reverse" do
    it "answers the place-summary frame with the place, the country, the coordinates and the data the finder copies" do
      get reverse_places_path(locale: "en", lat: "42.0307812", lon: "-93.6319131")

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/\A<turbo-frame[^>]*id="place-summary"/)
      expect(response.body).to include(I18n.t("places.reverse.near", place: "Ames, Iowa")).and include("United States")
      expect(response.body).to include(I18n.t("places.reverse.coordinates", latitude: "42.03078", longitude: "-93.63191"))
      expect(response.body).to include('data-latitude="42.0307812"').and include('data-longitude="-93.6319131"')
      expect(response.body).to include('data-place-label="Ames, Iowa"').and include('data-country-code="US"').and include('data-admin-area="Iowa"')
      expect(client).to have_received(:reverse).with(latitude: 42.0307812, longitude: -93.6319131, locale: :en)
    end

    it "names the place in Spanish under /es" do
      get reverse_places_path(locale: "es", lat: "4.6", lon: "-74.08")

      expect(client).to have_received(:reverse).with(latitude: 4.6, longitude: -74.08, locale: :es)
      expect(response.body).to include(I18n.t("places.reverse.near", place: "Ames, Iowa", locale: :es))
    end

    it "keeps the pin with a calm line when the geocoder fails" do
      allow(client).to receive_messages(reverse: nil, last_error: { type: :network_error })

      get reverse_places_path(locale: "en", lat: "42.0", lon: "-93.75")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("places.unavailable")).and include('data-latitude="42.0"')
      expect(response.body).not_to include("data-place-label")
    end

    it "says so when there is no place there, and keeps the pin" do
      allow(client).to receive_messages(reverse: nil, last_error: { type: :not_found })

      get reverse_places_path(locale: "en", lat: "0", lon: "0")

      expect(response.body).to include(I18n.t("places.reverse.no_name")).and include('data-latitude="0.0"')
    end

    it "rejects coordinates off the map without calling the geocoder" do
      get reverse_places_path(locale: "en", lat: "95", lon: "-93.75")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("places.reverse.invalid"))
      expect(response.body).not_to include("data-latitude")
      expect(client).not_to have_received(:reverse)
    end
  end
end
