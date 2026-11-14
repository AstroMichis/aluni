# /service -- Service Object Builder

You are creating a service object for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `app/services/application_service.rb` for the base class and helpers
2. Read `app/models/result.rb` for the Result API
3. Read the most similar existing service: `app/services/platform/toggle_service.rb` (writes a row, busts a cache), `app/services/core/normalize_service.rb` (wraps the Rust extension), `app/services/notification_router.rb` (orchestrates channels)
4. Read `docs/RAILS_PATTERNS.md`, service objects section
5. If the service touches an outside API, read `docs/INTEGRATIONS.md` and `app/services/gemini/client.rb`

## Result API

```ruby
Success(data)                           # Result::Success with value
Failure(code: :not_found, message: "")  # Result::Failure with an error hash

result.success? / result.failure?
result.value   # data on Success (also .data)
result.error   # error hash on Failure
result.bind { |val| another_result }    # chain if success, pass through if failure (also .and_then)
result.fmap { |val| transform(val) }    # map the value if success
result.or_else { |err| handle(err) }    # handle if failure
result.tee { |val| side_effect(val) }   # side effect if success, returns self
result.value_or(default)
case result
in Result::Success(value) then ...
in Result::Failure(code: :validation, messages:) then ...
in Result::Failure(error) then ...
end
```

## Service template

```ruby
# app/services/<domain>/<action>_service.rb
module <Domain>
  class <Action>Service < ApplicationService
    def initialize(user:, attrs:)
      @user = user
      @attrs = attrs
    end

    def call
      validated = step validate
      record    = step persist(validated)
      step notify(record)
      Success(record)
    end

    private

    def validate
      errors = []
      errors << I18n.t("service_errors.generic") if @attrs.blank?
      errors.any? ? Failure(code: :validation, messages: errors) : Success(@attrs)
    end

    def persist(attrs)
      record = @user.things.create(attrs)
      record.persisted? ? Success(record) : Failure(code: :validation, messages: record.errors.full_messages)
    end

    def notify(record)
      NotificationRouter.deliver(recipient: @user, purpose: :thing_created,
                                 payload: { mailer_args: [ @user, "...", "..." ], push: { path: "/app" } },
                                 idempotency_key: "thing:#{record.id}:created")
      Success(record)
    end
  end
end
```

## Key helpers

`step(result)` unwraps a Success and returns its value; on a Failure it halts the whole service and returns that Failure. `try_external(*exceptions) { }` wraps an outside call: listed exceptions become `Failure(code: :external_error, message:)` with a log line.

```ruby
def ask_gemini(prompt)
  try_external(Faraday::Error, JSON::ParserError) do
    text = Gemini::Client.new.generate(prompt, response_schema: SCHEMA)
    raise JSON::ParserError, "empty answer" if text.nil?   # the client returns nil on exhaustion
    JSON.parse(text)
  end
end
```

Pass a brace block to `try_external` when it is the argument of `step` (`step try_external(X) { ... }`); a `do ... end` block binds to `step`.

## Rules

- One service = one action, `<Verb>Service` (`CreateService`, `SendService`, `ExpireService`, `NormalizeService`)
- Domain folders under `app/services/`: `platform/` (switchboard), `gemini/`, `notifications/`, `core/` (Rust wrappers), then one per product domain
- Named keyword arguments in `initialize`; never `params`, `session`, `Current.user` inside a service; pass data in
- Never render or redirect; controllers do that
- Money as integer minor units or BigDecimal, never Float; default currency USD
- `ActiveRecord::Base.transaction` when several records must succeed together
- Outside calls go through a client that calls `Platform::Switchboard.guard!` (or a `Platform::FaradayPauseGuard`); `Platform::ServicePaused` propagates to `ApplicationController` and `ApplicationJob`
- Messages go through `NotificationRouter`, never a mailer directly
- Enqueue with `perform_later` and primitive arguments
- Handle every expected error explicitly; log with `Rails.logger.error("[ServiceName] ...")`

## Controller pattern matching

```ruby
def create
  case Things::CreateService.call(user: Current.user, attrs: thing_params)
  in Result::Success(thing)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.append("things", partial: "app/things/thing", locals: { thing: }) }
      format.html { redirect_to app_thing_path(thing), notice: t(".created") }
    end
  in Result::Failure(code: :validation, messages:)
    @errors = messages
    render :new, status: :unprocessable_content
  in Result::Failure(error)
    redirect_back fallback_location: app_root_path, alert: extract_error_message(error)
  end
end
```

## Testing template

```ruby
# spec/services/<domain>/<action>_service_spec.rb
require "rails_helper"

RSpec.describe Things::CreateService do
  let(:user) { create(:user) }

  it "returns a Success with the record" do
    result = described_class.call(user: user, attrs: valid_attrs)
    expect(result).to be_success
    expect(result.value).to be_a(Thing)
  end

  it "halts on validation and creates nothing" do
    expect { described_class.call(user: user, attrs: {}) }.not_to change(Thing, :count)
    expect(described_class.call(user: user, attrs: {}).error[:code]).to eq(:validation)
  end

  it "wraps an outside failure" do
    stub_request(:post, /generativelanguage/).to_return(status: 500)
    expect(described_class.call(user: user, attrs: valid_attrs).error[:code]).to eq(:external_error)
  end
end
```

Service specs include `Result::Mixin` (write `Success(...)` / `Failure(...)` directly). Stub outside APIs with WebMock; a spec that reaches Gemini without the `:gemini_api` tag fails the suite. Run: `mise exec -- bundle exec rspec <spec_file>`.
