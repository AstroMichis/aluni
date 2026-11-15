module Onboarding
  # One Gemini chat call that drafts Aluni's next line as structured JSON:
  # the text, whether the topic is done, an optional location guess and the
  # facts to stage. Every enum in RESPONSE_SCHEMA comes from the models through
  # Onboarding::Allowlist, so what the model may say is what the row accepts.
  # A paused switch is a Failure here, never an exception, because the caller
  # answers a fetch and must stay in character.
  class DraftReplyService < ApplicationService
    def self.enum(values) = { type: "string", enum: values }
    def self.list(values) = { type: "array", items: enum(values) }

    PROFILE_SCHEMA = {
      type: "object",
      properties: Allowlist::PROFILE_ENUMS.transform_values { |v| enum(v) }
        .merge(Allowlist::PROFILE_LISTS.transform_values { |v| list(v) })
        .merge("team_size" => { type: "integer" }, "notes" => { type: "string" })
    }.freeze
    FARM_SCHEMA = {
      type: "object",
      properties: { name: { type: "string" }, country_code: { type: "string" }, admin_area: { type: "string" } }
    }.freeze
    FIELD_SCHEMA = {
      type: "object",
      properties: {
        name: { type: "string" }, area: { type: "number" }, area_unit: enum(Allowlist::FIELD_ENUMS["area_unit"]),
        irrigation: enum(Allowlist::FIELD_ENUMS["irrigation"]), water_source: enum(Allowlist::FIELD_ENUMS["water_source"]),
        cropping_intensity: enum(Allowlist::FIELD_ENUMS["cropping_intensity"]),
        soil_texture: enum(Allowlist::SOIL_ENUMS["texture"]), soil_depth: enum(Allowlist::SOIL_ENUMS["depth"]),
        soil_drainage: enum(Allowlist::SOIL_ENUMS["drainage"]), soil_ph: { type: "number" },
        soil_salinity: enum(Allowlist::SOIL_ENUMS["salinity"]), soil_fertility: enum(Allowlist::SOIL_ENUMS["fertility"]),
        soil_lab_test: { type: "boolean" }, soil_problems: list(Allowlist::SOIL_PROBLEMS)
      }
    }.freeze
    CROP_SCHEMA = {
      type: "object",
      properties: {
        crop_name: { type: "string" }, scientific_name: { type: "string" }, season_year: { type: "integer" },
        planting_month: { type: "integer" }, harvest_month: { type: "integer" }, role: enum(Allowlist::CROP_ROLES)
      },
      required: %w[crop_name season_year role]
    }.freeze
    RESPONSE_SCHEMA = {
      type: "object",
      properties: {
        response_text: { type: "string" },
        topic_complete: { type: "boolean" },
        location_guess: {
          type: "object", nullable: true,
          properties: {
            latitude: { type: "number" }, longitude: { type: "number" }, label: { type: "string" },
            confidence: enum(Allowlist::LOCATION_CONFIDENCES)
          }
        },
        updates: {
          type: "object",
          properties: {
            profile: PROFILE_SCHEMA, farm: FARM_SCHEMA, field: FIELD_SCHEMA,
            crops: { type: "array", items: CROP_SCHEMA }
          }
        }
      },
      required: %w[response_text topic_complete]
    }.freeze

    def initialize(messages:, system_instruction:, client: nil)
      @messages = messages
      @system_instruction = system_instruction
      @client = client
    end

    def call
      parsed = step ask
      Success(parsed)
    rescue Platform::ServicePaused => e
      Rails.logger.warn("[Onboarding::DraftReplyService] #{e.message}")
      Failure(code: :paused, message: e.message)
    end

    private

    def ask
      try_external(Faraday::Error, JSON::ParserError) do
        text = client.chat(messages: @messages, system_instruction: @system_instruction,
                           response_schema: RESPONSE_SCHEMA, max_tokens: Rails.configuration.x.onboarding.max_output_tokens)
        raise JSON::ParserError, "no answer (#{client.last_error&.dig(:type) || 'unknown'})" if text.nil?

        parsed = JSON.parse(text)
        raise JSON::ParserError, "answer is not an object" unless parsed.is_a?(Hash)
        raise JSON::ParserError, "answer has no response_text" if parsed["response_text"].to_s.strip.empty?

        parsed
      end
    end

    def client
      @client ||= Gemini::Client.new(model: :flash, timeout: Rails.configuration.x.onboarding.gemini_timeout)
    end
  end
end
