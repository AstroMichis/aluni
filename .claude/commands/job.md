# /job -- Background Job Builder

You are creating a background job for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/RAILS_PATTERNS.md`, jobs section
2. Read `app/jobs/application_job.rb` (switchboard-aware base class)
3. Read `app/jobs/sessions/purge_stale_job.rb` (the cron example) and `app/jobs/notifications/web_push_job.rb`
4. Read `config/sidekiq.yml` (queues) and `config/sidekiq_cron.yml` (schedule)

## Job template

```ruby
# app/jobs/<domain>/<name>_job.rb
module <Domain>
  class <Name>Job < ApplicationJob
    queue_as :default   # must be listed in config/sidekiq.yml: default, gemini, push, webhooks, maintenance

    retry_on Faraday::Error, wait: :polynomially_longer, attempts: 5

    def perform(record_id)
      record = Model.find_by(id: record_id)
      return unless record   # deleted since enqueue: nothing to do

      case Domain::ActionService.call(record: record)
      in Result::Success then logger.info("[#{self.class.name}] done for #{record_id}")
      in Result::Failure(error) then logger.error("[#{self.class.name}] #{record_id}: #{error[:message]}")
      end
    end
  end
end
```

## Rules

- Primitive arguments only (ids, strings, numbers); never ActiveRecord objects
- Find records inside `perform`; handle a missing record gracefully
- `ApplicationJob` already has `retry_on ActiveRecord::Deadlocked`, `discard_on ActiveJob::DeserializationError`, and the switchboard hold: while `jobs` is paused every job waits 15 minutes and re-checks; while `cron` is paused cron jobs are skipped; a queue in `QUEUE_SERVICES` (`gemini`, `push`) is held while its service is paused. Add a queue there when a new outside service gets its own queue.
- Delegate logic to a service object; the job is scheduling and logging
- Idempotency: jobs may run twice; check state before acting or use an idempotency key (`NotificationRouter` does)
- Jobs never read the request; whatever they need arrives as an argument

## Queues (`config/sidekiq.yml`)

`default` (most jobs), `gemini` (every job that calls Gemini), `push` (notification delivery), `webhooks` (inbound event processing), `maintenance` (cron cleanups). Add a queue to the file when you declare it, or the job is enqueued and never runs. Keep `SIDEKIQ_CONCURRENCY` <= `RAILS_MAX_THREADS` on the worker.

## Scheduled jobs (`config/sidekiq_cron.yml`)

```yaml
thing_cleanup:
  cron: "0 4 * * *"   # 04:00 UTC daily (the app runs in UTC)
  class: "Things::CleanupJob"
  queue: maintenance
  description: "What it does"
```

Loaded by `config/initializers/sidekiq.rb`; `Platform::CronControl` disables every entry while `cron` or `jobs` is paused. `spec/jobs/sessions/purge_stale_job_spec.rb` shows how to assert the entry's class and queue.

## Testing

```ruby
require "rails_helper"

RSpec.describe Things::CleanupJob do
  it "does the work" do
    thing = create(:thing)
    described_class.perform_now(thing.id)
    expect(thing.reload).to be_cleaned
  end

  it "ignores a missing record" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  it "is held while its service is paused" do
    create(:platform_switch, service: "jobs", paused: true)
    expect { described_class.perform_now(1) }.to have_enqueued_job(described_class)
  end
end
```

The test adapter is global (`config/environments/test.rb`); `have_enqueued_job(...).with(args).on_queue("default")` checks enqueuing from services. Run: `mise exec -- bundle exec rspec <spec_file>`.
