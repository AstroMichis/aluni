class ApplicationJob < ActiveJob::Base
  # How long a job held by a platform pause waits before it checks again.
  PAUSE_RECHECK = 15.minutes

  # Queues whose jobs exist to call one outside service; pausing the service
  # holds the whole queue instead of letting each job fail at the client.
  QUEUE_SERVICES = { "gemini" => :gemini, "push" => :push }.freeze

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # A client refused the call because the operator paused its service.
  rescue_from(Platform::ServicePaused) { |error| hold_for_pause(error.service) }

  around_perform do |job, block|
    service = job.paused_service
    service ? job.hold_for_pause(service) : block.call
  end

  def paused_service
    return "jobs" if Platform::Switchboard.paused?(:jobs)
    return "cron" if cron_job? && Platform::Switchboard.paused?(:cron)

    service = QUEUE_SERVICES[queue_name.to_s]
    service.to_s if service && Platform::Switchboard.paused?(service)
  end

  # Cron jobs are dropped (the next tick runs them again); anything else waits
  # and re-checks, so a pause loses no work.
  def hold_for_pause(service)
    if cron_job?
      logger.info("[platform] skipped #{self.class.name}: #{service} paused")
    else
      logger.info("[platform] held #{self.class.name} #{PAUSE_RECHECK.inspect}: #{service} paused")
      retry_job(wait: PAUSE_RECHECK)
    end
  end

  private

  def cron_job?
    Platform::CronControl.cron_job?(self.class.name)
  end
end
