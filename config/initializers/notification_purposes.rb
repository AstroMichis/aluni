# Fail at boot, not at the first message, when config/notification_purposes.yml
# is malformed. Skipped in test, where specs load the registry on demand.
Rails.application.config.after_initialize do
  Notifications::Purposes.current unless Rails.env.test?
end
