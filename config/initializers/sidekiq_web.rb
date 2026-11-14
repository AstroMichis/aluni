# Sidekiq Web is mounted at /sidekiq on ADMIN_HOST only when both values are
# set (config/routes.rb): HTTP basic auth over TLS, compared with
# secure_compare. Leave them unset to keep the dashboard unmounted.
Rails.application.config.x.sidekiq_web.username = ENV["SIDEKIQ_WEB_USERNAME"].presence
Rails.application.config.x.sidekiq_web.password = ENV["SIDEKIQ_WEB_PASSWORD"].presence
