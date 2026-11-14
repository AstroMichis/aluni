# Boot-time guard for Active Record encryption. Without keys, the first read or
# write of an encrypted column raises deep inside a request; fail at boot
# instead, with instructions.
module ActiveRecordEncryptionCheck
  KEYS = %i[primary_key deterministic_key key_derivation_salt].freeze

  class MissingKeysError < StandardError; end

  module_function

  def enforce?(env: Rails.env, dummy_build: ENV["SECRET_KEY_BASE_DUMMY"].present?)
    env.production? && !dummy_build
  end

  def missing_keys(config = ActiveRecord::Encryption.config)
    KEYS.reject { |key| configured?(config, key) }
  end

  def verify!(config = ActiveRecord::Encryption.config)
    missing = missing_keys(config)
    return if missing.empty?

    raise MissingKeysError, <<~MSG.squish
      Active Record encryption keys missing: #{missing.join(', ')}.
      Generate them with `bin/rails db:encryption:init` and store them under
      active_record_encryption in the production credentials, or set
      #{missing.map { |k| "ACTIVE_RECORD_ENCRYPTION_#{k.upcase}" }.join(', ')}.
    MSG
  end

  # Development only: placeholder keys for whichever of the three keys the
  # development credentials and ENV leave out, so a fresh clone boots without
  # them. Never used in production (verify! guards that) or test.
  def development_fallback_keys(credentials:, env: ENV)
    KEYS.each_with_object({}) do |key, keys|
      next if credentials.to_h.with_indifferent_access[key].present?
      next if env["ACTIVE_RECORD_ENCRYPTION_#{key.upcase}"].present?

      keys[key] = "development-only-#{key.to_s.dasherize}-not-a-secret"
    end
  end

  def configured?(config, key)
    config.public_send(key).present?
  rescue ActiveRecord::Encryption::Errors::Configuration
    false
  end
end
