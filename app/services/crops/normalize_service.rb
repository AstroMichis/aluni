module Crops
  # Turns what a farmer typed as the crop on their field into a common name and a
  # species: the built-in catalog first (free, instant), otherwise one short
  # Gemini call with a strict schema. Anything the model is not sure about, a
  # failure or a paused switch falls back to the typed text with confidence
  # "low"; the service never fails for the caller, who always has something to save.
  class NormalizeService < ApplicationService
    TEXT_MAX = FieldCrop::NAME_MAX
    CONFIDENCES = %w[low medium high].freeze
    ACCEPTED = %w[medium high].freeze
    PERSONA = <<~PERSONA
      You help an agricultural app understand what a farmer grows. The farmer typed the name
      of the crop on their field, in any language, often a regional or informal name.
      Answer with the crop's common name (in the locked language, capitalised as a name) and
      its scientific species name in Latin (genus and species). If the text is not a crop,
      or you are not sure which species it is, set confidence to "low".
    PERSONA
    RESPONSE_SCHEMA = {
      type: "object",
      properties: {
        crop_name: { type: "string" },
        scientific_name: { type: "string" },
        confidence: { type: "string", enum: CONFIDENCES }
      },
      required: %w[crop_name scientific_name confidence]
    }.freeze

    def initialize(text:, locale: I18n.locale)
      @text = text
      @locale = locale
    end

    def call
      text = @text.to_s.squish.first(TEXT_MAX)
      return Failure(code: :empty) if text.blank?

      if (hit = Catalog.find(text, locale: @locale))
        return Success(crop_name: hit[:crop_name], scientific_name: hit[:scientific_name], confidence: "high", key: hit[:key])
      end

      Success(ask_gemini(text) || fallback(text))
    end

    private

    def ask_gemini(text)
      return nil unless Platform::Features.gemini?

      result = try_external(Faraday::Error, JSON::ParserError) do
        client = Gemini::Client.new(model: :flash, timeout: 10)
        raw = client.generate(prompt_for(text), system_instruction: system_instruction, response_schema: RESPONSE_SCHEMA, max_tokens: 128)
        raw.nil? ? nil : JSON.parse(raw)
      end
      answer = result.success? ? result.value : nil
      answer.is_a?(Hash) ? accept(answer) : nil
    end

    def accept(answer)
      confidence = answer["confidence"].to_s
      name = answer["crop_name"].to_s.squish.first(TEXT_MAX)
      return nil unless ACCEPTED.include?(confidence) && name.present?

      { crop_name: name, scientific_name: answer["scientific_name"].to_s.squish.first(TEXT_MAX).presence, confidence: confidence }
    end

    def fallback(text)
      { crop_name: text, scientific_name: nil, confidence: "low" }
    end

    def system_instruction
      Gemini::LanguagePrompt.lock(@locale) + "\n" + PERSONA
    end

    def prompt_for(text)
      "The farmer typed: #{text.inspect}"
    end
  end
end
