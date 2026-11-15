# frozen_string_literal: true

module Demo
  # Fills an account that already signed up (passkeys only: nothing here signs
  # anyone in) with one of the sample farms in config/demo_farms.yml: the
  # finished profile, the farm, a located field with four seasons of history,
  # and the public data at its pin (the new pin enqueues
  # Fields::FetchObservationsJob, as in the app; running the job here too would
  # race the worker for the same rows). Running it again
  # replaces that sample farm only. It refuses an account with other farms
  # unless forced, so a real farmer's data is never overwritten by mistake.
  class FarmService < ApplicationService
    PATH = Rails.root.join("config/demo_farms.yml")

    def self.presets = YAML.safe_load(File.read(PATH))
    def self.names = presets.map { |_, p| p.dig("farm", "name") }

    def initialize(user:, preset:, force: false)
      @user = user
      @preset = self.class.presets[preset.to_s]
      @force = force
    end

    def call
      return Failure(code: :unknown_preset) unless @preset
      return Failure(code: :not_found) unless @user

      others = @user.farms.where.not(name: self.class.names)
      return Failure(code: :has_farms, count: others.count) if others.exists? && !@force

      Success(ActiveRecord::Base.transaction { build })
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def build
      @user.update!(locale: @preset["locale"])
      profile = @user.farmer_profile || @user.build_farmer_profile
      profile.update!(@preset["profile"])
      session = @user.onboarding_session || @user.build_onboarding_session
      session.update!(status: :completed, completed_at: Time.current, topic: "summary", language: @preset["locale"])

      @user.farms.where(name: @preset.dig("farm", "name")).destroy_all
      farm = @user.farms.create!(@preset["farm"])
      field = farm.fields.create!(@preset["field"].merge(location_confidence: :confirmed, location_source: :map))
      @preset["crops"].each do |crop|
        field.field_crops.create!(crop.except("season").merge(season_year: Date.current.year + crop["season"], role: :main, source: :farmer))
      end
      field
    end
  end
end
