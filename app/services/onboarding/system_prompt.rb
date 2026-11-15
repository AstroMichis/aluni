module Onboarding
  # The system instruction Aluni speaks from on every turn: persona, the
  # language lock, the current topic with its guidance and required facts, the
  # field basics settled during setup, the profile so far, the global rules
  # from topics.yml and the output rules for the structured answer.
  # spec/fixtures/onboarding/system_prompt.txt is the golden master of the
  # result for a fixed snapshot.
  module SystemPrompt
    PERSONA = <<~TEXT
      You are %{name}, a friendly seedling who helps a farmer complete their field profile in a short chat and answers questions about the field.
      Speak in the first person as %{name}. Use plain, warm words for people who are not comfortable with technology.
      Every reply is two short sentences and then exactly one question.
      You are %{name} and nothing else: never describe yourself as an AI, a model, a bot or a program.
      You are talking with %{farmer}.
    TEXT

    OUTPUT_RULES = <<~TEXT
      OUTPUT RULES:
      - response_text is what the farmer reads. Keep it short and warm, in the locked language.
      - updates holds only facts the farmer actually said in this conversation. Never guess, infer defaults or copy from PROFILE SO FAR.
      - Use the allowed words for every choice exactly as listed; when nothing fits, leave that field out.
      - Every crops row carries crop_name, scientific_name, season_year and role.
      - Set topic_complete to true only when the required facts of the current topic are known or the farmer says they do not know them.
      - The field pin is settled: leave location_guess empty unless the farmer says the pin is wrong and names a new place; confidence is never high for a place name.
    TEXT

    BASICS_HEADER = "KNOWN FIELD BASICS (settled during setup; use them, never ask for them again):"
    NOT_SET = "not set"

    module_function

    def build(snapshot:, topic:, locale:, display_name:, opening: nil)
      required = Topics.required(topic)
      sections = [
        format(PERSONA, name: I18n.t("onboarding.persona_name", locale: locale), farmer: display_name.to_s.strip).strip,
        Gemini::LanguagePrompt.lock(locale).strip,
        "CURRENT TOPIC: #{topic}\nREQUIRED FACTS: #{required.any? ? required.join(', ') : 'none'}",
        "TOPIC GUIDANCE:\n#{Topics.guidance(topic)}",
        "#{BASICS_HEADER}\n#{known_basics(snapshot)}",
        "PROFILE SO FAR:\n#{snapshot.to_prompt}",
        "RULES:\n#{Topics.rules}",
        OUTPUT_RULES.strip
      ]
      sections << "OPENING LINE ALREADY SHOWN TO THE FARMER (do not greet again):\n#{opening}" if opening.present?
      sections.join("\n\n")
    end

    # The pin, the place, the crop on the field now, the irrigation and the
    # area from the snapshot, one line each, "not set" where setup left a gap.
    def known_basics(snapshot)
      data = snapshot.to_h
      field = data[:field] || {}
      farm = data[:farm] || {}
      crop = Array(data[:crops]).first || {}
      [
        "- pin: #{pin_line(field)}",
        "- place: #{[ field[:place_label], farm[:admin_area], farm[:country_code] ].compact_blank.join(', ').presence || NOT_SET}",
        "- crop now: #{crop_line(crop)}",
        "- irrigation: #{field[:irrigation].presence || NOT_SET}",
        "- area: #{field[:area] ? "#{field[:area]} #{field[:area_unit]}" : NOT_SET}"
      ].join("\n")
    end

    def pin_line(field)
      return NOT_SET unless field[:latitude] && field[:longitude]

      "#{field[:latitude]}, #{field[:longitude]} (#{field[:location_confidence] || 'unknown'})"
    end

    def crop_line(crop)
      return NOT_SET if crop[:crop_name].blank?

      name = crop[:scientific_name].present? ? "#{crop[:crop_name]} (#{crop[:scientific_name]})" : crop[:crop_name].to_s
      "#{name}, #{crop[:season_year]} season"
    end
  end
end
