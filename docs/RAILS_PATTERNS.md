# Rails patterns

## Service objects

One service = one action, named `<Verb>Service` under `app/services/<domain>/`, keyword arguments in `initialize`, a `Result` from `call`. Services never read `params`, `session` or the current user, never render, never redirect.

```ruby
module Core
  class NormalizeService < ApplicationService
    def initialize(input:)
      @input = input
    end

    def call
      value = step normalize          # step unwraps a Success or halts the call with the Failure
      Success(value)
    end

    private

    def normalize
      Success(AluniCore.normalize(@input.to_s))
    rescue ArgumentError, RuntimeError, AluniCore::Error => e
      Failure(code: :core_error, message: e.message)
    end
  end
end
```

`Result::Success` / `Result::Failure` (`app/models/result.rb`) support `success?`, `value`, `error`, `bind`, `fmap`, `or_else`, `tee`, `value_or` and pattern matching. `try_external(*exceptions) { }` wraps an outside call and turns the listed exceptions into `Failure(code: :external_error)`. Multi-record writes go in `ActiveRecord::Base.transaction`. Jobs are enqueued with `perform_later` and primitive arguments.

## Controllers

Thin: find, call a service, respond. Pattern match the result:

```ruby
case Some::CreateService.call(user: Current.user, attrs: thing_params)
in Result::Success(thing)
  redirect_to app_thing_path(thing), notice: t(".created")
in Result::Failure(code: :validation, messages:)
  render :new, status: :unprocessable_content
in Result::Failure(error)
  redirect_back fallback_location: app_root_path, alert: extract_error_message(error)
end
```

Base classes: `ApplicationController` (Authentication, locale switching, `rescue_from Platform::ServicePaused`), `App::BaseController` (authentication + Pundit + the NativeOnly kill switch, layout `application`), `Api::V1::BaseController` (`ActionController::API`, session cookie + `X-Aluni-Native` header), `PagesController` (public layout). Turbo-compatible statuses: `:unprocessable_content` on failed forms, `:see_other` on redirects after non-GET.

## Authentication and the native gate

See `docs/AUTH.md`. `allow_unauthenticated_access` opens an action; `require_authentication` is the default. `NativeOnly` is the kill switch that closes a controller to browsers when `NATIVE_WEB_ACCESS=0`; the shells always pass.

## Hotwire

Turbo Drive everywhere; Turbo Frames for sections that update independently; Turbo Streams for broadcasts; `shared/flash_stream.turbo_stream.erb` updates `#flash`. Stimulus handles interactivity, never server state: controllers in `app/javascript/controllers/` are auto-registered (subfolders become `folder--name`, e.g. `bridge--share`). Every controller cleans up in `disconnect()` (listeners, timers, observers, animation frames). Heavy libraries are vendored and loaded lazily with `await import("three")`. Native `<dialog>` for modals (`dialog_controller.js`).

## The onboarding chat (`docs/ONBOARDING.md`)

A chat turn is one request a person is waiting on, so `App::OnboardingController#message` calls `Onboarding::ReplyService` inline and answers a Turbo Stream (`message.turbo_stream.erb`: the two bubbles, the confirm card, the progress dots). The Stimulus `chat` controller posts the composer with `Accept: text/vnd.turbo-stream.html` and renders whatever stream comes back, whatever the status (a 429 notice is a stream too). Rules that keep it safe: the service never raises out (a Gemini failure or a paused switch becomes an in-character continuation line, `degraded: true`); `Platform::ServicePaused` is rescued inside `Onboarding::DraftReplyService`, never left to `ApplicationController`'s redirect, which a fetch could not follow; the safety classifier runs in a `Thread` wrapped in `Rails.application.executor.wrap` with its own `Gemini::Client`, every DB read happens before the thread starts, only `Service.call` runs inside it (never `step`, whose `throw :halt` belongs to the calling service), `join(timeout)` and an unfinished classifier counts as safe; nothing the model proposes is saved until the person ticks it on the confirm card (`Onboarding::ApplyProposalService` re-filters through `Onboarding::Allowlist`).

## Jobs

`ApplicationJob`: `retry_on ActiveRecord::Deadlocked`, `discard_on ActiveJob::DeserializationError`, `rescue_from Platform::ServicePaused`, and an `around_perform` that consults the switchboard: cron jobs are skipped while `cron` or `jobs` is paused, other jobs retry in 15 minutes. `QUEUE_SERVICES` maps a queue to its outside service (`gemini`, `push`) so pausing the service holds the queue. Rules: primitive arguments, find records inside `perform`, one job per concern, `queue_as` a queue listed in `config/sidekiq.yml`, cron entries in `config/sidekiq_cron.yml` (UTC) with a class on a listed queue (`spec/jobs/sessions/purge_stale_job_spec.rb` checks this shape).

## The switchboard

`Platform::Switchboard.paused?(:gemini)` / `guard!(:gemini)` read `PlatformSwitch` rows (15 s cache, fails open, `PLATFORM_PAUSE_ALL=1` brake). `Platform::ToggleService` writes them, busts the cache and syncs sidekiq-cron. Clients call `guard!` right before the HTTP request (`Gemini::Client#post_and_extract`), or mount `Platform::FaradayPauseGuard`. The mail interceptor drops mail while `mail` is paused (critical mail carries `X-Platform-Critical`). Operator surface: `bin/rails platform:{pause,resume,pause_all,resume_all,bootstrap,status}` and the GitHub workflow.

## Models

`null: false` on required columns, integer-backed enums with `default: 0, null: false`, `jsonb` with a default for flexible data, money as integer minor units or `decimal` (never Float), `encrypts` for sensitive columns, `rails generate migration` always. Structure order: associations, enums, encrypts, scopes, validations, callbacks, public methods, private methods. Per-request context lives in `Current` (session, user), never read by services or jobs.

## Notifications

App code never calls a mailer or a push sender; it calls `NotificationRouter.deliver(recipient:, purpose:, payload:, idempotency_key:)`. Purposes live in `config/notification_purposes.yml` and are validated at boot (`Notifications::Purposes`); channels (`push`, `web_push`, `email`) are tried in order and every attempt is recorded on a `NotificationDelivery`.
