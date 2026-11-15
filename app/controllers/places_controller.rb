# Place search and reverse geocoding for the field finder (Geocoding::Client,
# Nominatim). Both actions answer a Turbo Frame, never JSON: index fills
# #place-results with a listbox of up to five places, reverse fills
# #place-summary with the place around a pin. A failure or a paused switch
# renders the same frame with a calm line and 200, because a frame cannot follow
# the redirect ApplicationController would answer with.
class PlacesController < ApplicationController
  allow_unauthenticated_access
  layout false

  # GET /places?q=
  def index
    @query = params[:q].to_s.squish.first(Geocoding::Client::QUERY_MAX)
    @results = @query.blank? ? [] : Geocoding::Client.new.search(@query, locale: I18n.locale)
    render partial: "places/results", locals: { query: @query, results: @results }
  end

  # GET /places/reverse?lat=&lon=
  def reverse
    latitude = Onboarding::Allowlist.coerce(params[:lat], :latitude)
    longitude = Onboarding::Allowlist.coerce(params[:lon], :longitude)
    place = nil
    unavailable = false
    if latitude && longitude
      client = Geocoding::Client.new
      place = client.reverse(latitude: latitude, longitude: longitude, locale: I18n.locale)
      unavailable = place.nil? && client.last_error&.dig(:type) != :not_found
    end
    render partial: "places/summary", locals: { latitude: latitude, longitude: longitude, place: place, unavailable: unavailable }
  end
end
