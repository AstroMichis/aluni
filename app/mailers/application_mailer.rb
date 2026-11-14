class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.credentials.dig(:mailer, :from).presence || ENV["MAILER_FROM"].presence || "no-reply@#{APP_DOMAIN}" }
  layout "mailer"
end
