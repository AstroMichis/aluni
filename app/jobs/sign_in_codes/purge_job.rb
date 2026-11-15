module SignInCodes
  # Scheduled daily (config/sidekiq_cron.yml): sign-in codes live ten minutes
  # and native hand-off tokens two; both are kept a day for the audit trail, then go.
  class PurgeJob < ApplicationJob
    queue_as :maintenance

    KEEP_FOR = 1.day

    def perform
      count = SignInCode.where(created_at: ...KEEP_FOR.ago).delete_all
      handoffs = AuthHandoff.where(created_at: ...KEEP_FOR.ago).delete_all
      logger.info("[auth] purged #{count} sign-in code(s) and #{handoffs} hand-off token(s)")
    end
  end
end
