module Gemini
  # Shared LANGUAGE LOCK block embedded in every Gemini system prompt, so the
  # model answers in the conversation locale and never drifts.
  module LanguagePrompt
    NAMES = { "es" => "Spanish", "en" => "English" }.freeze

    def self.lock(language)
      name = name_for(language)
      <<~LOCK
        LANGUAGE LOCK, ABSOLUTE:
        - ALWAYS respond in #{name}. EVERY response. No exceptions.
        - If the user writes in a different language than the lock, STILL respond in #{name}.
        - Do NOT acknowledge a language switch. Do NOT translate. Do NOT mix languages within a response.
        - If the user mixes languages mid-message, respond entirely in #{name}.
      LOCK
    end

    def self.name_for(language)
      NAMES.fetch(language.to_s, NAMES["en"])
    end
  end
end
