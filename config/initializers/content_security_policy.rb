# Be sure to restart your server when you modify this file.

# Application-wide content security policy. Every script is served by the app
# itself (importmap + vendored libraries), so script-src is :self plus the
# per-request nonce that covers the inline importmap tags. Google Fonts are the
# only outside hosts.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self
    policy.frame_ancestors :self
    policy.base_uri    :self
    policy.form_action :self
  end

  # Generate nonces for permitted importmap inline scripts.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
