# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# Symbols match partially (:name also filters display_name); regexes are
# anchored where a partial match would hide harmless keys.
Rails.application.config.filter_parameters += [
  # Credentials and token-ish values
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :authorization, :signature, /\Acode\z/i, /\Astate\z/i,
  # Passkey ceremony payloads
  :credential, :attestation, :assertion, :clientDataJSON, :authenticatorData, :userHandle,
  # Identity and contact PII
  :email, :phone, :name
]
