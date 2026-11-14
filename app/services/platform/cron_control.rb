# frozen_string_literal: true

module Platform
  # Mirrors the cron and jobs switches onto sidekiq-cron: while either is
  # paused every schedule entry is disabled so nothing is enqueued at all.
  # Runs after every toggle and when Sidekiq starts, because loading
  # config/sidekiq_cron.yml re-enables every entry.
  module CronControl
    SCHEDULE_FILE = Rails.root.join("config", "sidekiq_cron.yml")

    module_function

    def sync!
      hold = Switchboard.paused?(:cron) || Switchboard.paused?(:jobs)
      Sidekiq::Cron::Job.all.each do |job|
        if hold && job.enabled?
          job.disable!
        elsif !hold && job.disabled?
          job.enable!
        end
      end
    rescue RedisClient::Error, Redis::BaseError => e
      Rails.logger.error("[Platform::CronControl] could not sync cron state: #{e.message}")
    end

    # Job classes scheduled by cron. A held cron job is dropped, not delayed:
    # the next tick runs it again.
    def cron_class_names
      @cron_class_names ||= begin
        schedule = SCHEDULE_FILE.exist? ? YAML.load_file(SCHEDULE_FILE) : {}
        schedule.values.filter_map { |entry| entry["class"] }.to_set.freeze
      end
    end

    def cron_job?(job_class_name)
      cron_class_names.include?(job_class_name.to_s)
    end
  end
end
