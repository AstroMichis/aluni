module Sessions
  # Scheduled daily (config/sidekiq_cron.yml). Sign-in sessions are permanent
  # cookies on the device; Authentication#resume_session touches the row at
  # most once a day, so updated_at is "last seen". Rows unused for a year go.
  class PurgeStaleJob < ApplicationJob
    queue_as :maintenance

    STALE_AFTER = 1.year

    def perform
      count = Session.where(updated_at: ...STALE_AFTER.ago).delete_all
      logger.info("[sessions] purged #{count} stale session(s)")
    end
  end
end
