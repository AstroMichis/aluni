# Canonical host of this deployment. Production sets APP_DOMAIN in
# config/deploy.yml. Development defaults to localhost because passkeys
# (WebAuthn) only work on a secure context, and localhost is the one plain-http
# origin browsers treat as secure.
APP_DOMAIN = ENV.fetch("APP_DOMAIN") { Rails.env.production? ? "aluni.us" : "localhost" }
APP_PORT = ENV.fetch("APP_PORT", nil)

# Hosts allowed to serve operator surfaces (Sidekiq Web at /sidekiq, see
# config/routes.rb and lib/admin_host_constraint.rb). ADMIN_HOST may list
# several comma-separated hosts; the first one is canonical. The test default
# covers the Rails integration-session host.
module AdminHosts
  module_function

  def resolve(value, rails_env:, app_domain:)
    default = rails_env.to_s == "test" ? "www.example.com,admin.#{app_domain}" : app_domain
    (value.presence || default).split(",").map { |h| h.strip.downcase }.reject(&:empty?)
  end
end

ADMIN_HOSTS = AdminHosts.resolve(ENV["ADMIN_HOST"], rails_env: Rails.env, app_domain: APP_DOMAIN).freeze
ADMIN_HOST = ADMIN_HOSTS.first
