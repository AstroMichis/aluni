# Operator pause switches (app/services/platform/). The interceptor is
# registered after boot so the autoloaded constant resolves.
Rails.application.config.after_initialize do
  ActionMailer::Base.register_interceptor(Platform::MailPauseInterceptor)
end
