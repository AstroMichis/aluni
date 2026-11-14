Sidekiq.configure_server do |config|
  config.redis = REDIS_CONFIG

  schedule_file = Rails.root.join("config", "sidekiq_cron.yml")
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end

  # Loading the schedule re-enables every entry; re-apply the operator's cron
  # and jobs pauses once the app is booted.
  config.on(:startup) { Platform::CronControl.sync! }
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIG
end
