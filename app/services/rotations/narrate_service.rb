# frozen_string_literal: true

module Rotations
  # Puts one strategy's "why" into two plain sentences for the farmer, from
  # the facts Rotations::Comparator found (never anything else). Cached per
  # set of facts and language; Failure when Gemini is paused, unconfigured or
  # silent, and the screen keeps its rule-based text.
  class NarrateService < ApplicationService
    CACHE_TTL = 30.days
    MAX_TOKENS = 220

    def initialize(facts:, locale:, client: nil)
      @facts = facts
      @locale = locale.to_s
      @client = client
    end

    def call
      return Failure(code: :unconfigured) unless Gemini::Client.configured?

      key = "rotations/why/v1/#{@locale}/#{Digest::SHA256.hexdigest(@facts.to_json)}"
      text = Rails.cache.read(key) || generate
      return Failure(code: :external_error) if text.blank?

      Rails.cache.write(key, text, expires_in: CACHE_TTL)
      Success(text)
    rescue Platform::ServicePaused
      Failure(code: :paused)
    end

    private

    def generate
      client = @client || Gemini::Client.new(model: :flash, timeout: 15)
      client.generate(prompt, system_instruction: system_instruction, max_tokens: MAX_TOKENS)&.strip
    end

    def system_instruction
      <<~TEXT
        You are Aluni, a crop rotation assistant for farmers. #{Gemini::LanguagePrompt.lock(@locale)}
        Explain in at most two short sentences why this rotation strategy is worth considering, using only the facts given.
        Plain words a farmer uses; no numbers that are not in the facts; never say "AI" or "model"; no lists, no markdown.
        End by reminding that local advice and their own experience come first only if the facts include a risk.
      TEXT
    end

    def prompt = "FACTS (JSON):\n#{@facts.to_json}"
  end
end
