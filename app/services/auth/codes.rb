module Auth
  # The code itself: six uniform digits, stored only as an HMAC over the
  # destination and the code (so equal codes on different addresses never share
  # a digest), compared in constant time.
  module Codes
    LENGTH = 6

    module_function

    def generate = format("%0#{LENGTH}d", SecureRandom.random_number(10**LENGTH))

    def normalize(code) = code.to_s.gsub(/\D/, "")

    def digest(destination, code) = OpenSSL::HMAC.hexdigest("SHA256", key, "#{destination}:#{normalize(code)}")

    def match?(record, code)
      ActiveSupport::SecurityUtils.secure_compare(record.code_digest.to_s, digest(record.destination, code))
    end

    def key
      @key ||= Rails.application.key_generator.generate_key("sign_in_codes", 32)
    end
  end
end
