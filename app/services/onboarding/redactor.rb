module Onboarding
  # Scrubs what a farmer types before it is stored, echoed or sent out: emails
  # and phone-shaped digit groups become placeholders, tags are dropped, the
  # text is capped. Decimal numbers such as 42.0123 or -93.75 are left alone
  # so typed coordinates, areas and pH values survive.
  module Redactor
    MAX_LENGTH = 2000
    MIN_PHONE_DIGITS = 7
    EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/
    # A run of digits with the separators people put in phone numbers.
    DIGIT_RUN = /\+?[(\d][\d\s().-]*\d\)?/
    DECIMAL = /\A[+-]?\d+\.\d+\z/
    TAG = %r{</?[A-Za-z][^>]*>}

    module_function

    def redact(text)
      value = text.to_s.gsub(TAG, " ")
      value = value.gsub(EMAIL, "[email]")
      value = value.gsub(DIGIT_RUN) { |run| redact_run(run) }
      value.gsub(/[ \t]+/, " ").gsub(/\s*\n\s*/, "\n").strip[0, MAX_LENGTH]
    end

    # Within a run, decimal tokens stay; the other tokens form groups, and a
    # group with enough digits is a phone number.
    def redact_run(run)
      groups = run.split(/(\s+)/).chunk_while { |a, b| !decimal?(a) && !decimal?(b) }
      groups.map do |tokens|
        joined = tokens.join
        phone?(joined) ? joined.sub(/\A(\s*)(.*?)(\s*)\z/m, "\\1[phone]\\3") : joined
      end.join
    end

    def decimal?(token) = DECIMAL.match?(token.strip)

    def phone?(group)
      group.count("0-9") >= MIN_PHONE_DIGITS && !decimal?(group)
    end
  end
end
