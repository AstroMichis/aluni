# frozen_string_literal: true

module Earthdata
  # An Earthdata Login bearer token for the team's account
  # (EARTHDATA_USERNAME / EARTHDATA_PASSWORD in the credentials), from
  # find_or_create_token: the account's current token, or a new one when it has
  # none (EDL allows two at a time). Cached until a day before it expires.
  # Files behind EDL (PO.DAAC's protected archive) take it as
  # `Authorization: Bearer`. AppEEARS has its own login (Appeears::Client).
  module Token
    URL = "https://urs.earthdata.nasa.gov/api/users/find_or_create_token"
    KEY = "earthdata/token/v1"

    module_function

    def fetch(cache: Rails.cache)
      cache.read(KEY) || create(cache)
    end

    def reset!(cache: Rails.cache) = cache.delete(KEY)

    def create(cache)
      credentials = Rails.application.credentials
      unless credentials.EARTHDATA_USERNAME.present? && credentials.EARTHDATA_PASSWORD.present?
        raise DataSources::Client::Error, "Earthdata credentials are missing"
      end

      Platform::Switchboard.guard!(:data)
      response = Faraday.new do |f|
        f.request :authorization, :basic, credentials.EARTHDATA_USERNAME, credentials.EARTHDATA_PASSWORD
        f.response :json
        f.options.timeout = 30
      end.post(URL)
      token = response.body.is_a?(Hash) ? response.body["access_token"] : nil
      raise DataSources::Client::Error, "Earthdata token request failed (#{response.status})" unless response.success? && token

      expires = Date.strptime(response.body["expiration_date"].to_s, "%m/%d/%Y") rescue nil
      ttl = expires ? [ (expires - 1 - Date.current).to_i.days, 1.hour ].max : 7.days
      cache.write(KEY, token, expires_in: ttl)
      token
    rescue Faraday::Error => e
      raise DataSources::Client::Error, "Earthdata token: #{e.class.name.demodulize} #{e.message}".truncate(250)
    end
  end
end
