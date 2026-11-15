# /test -- Test Writer

You are writing RSpec tests for Aluni. The target is: $ARGUMENTS

## Before writing tests:

1. Read the file(s) under test
2. Read `spec/rails_helper.rb` and `spec/support/` (authentication helpers, passkeys, external_apis, cuprite, vcr)
3. Read existing specs in the same directory for patterns
4. Read `spec/factories/`

## Factories

`:user` (traits `:with_email`, `:spanish`), `:passkey`, `:session`, `:platform_switch`, `:farmer_profile` (trait `:blank`), `:farm`, `:field` (trait `:unlocated`), `:field_crop`, `:onboarding_session` (trait `:completed`). Add one per new model (`spec/factories/<plural>.rb`, generated with the model).

## Helpers

- `native_headers` (a Hotwire Native user agent), `sign_in_as(user)` (opens a Session and sets the signed cookie), `with_native_web_access(true) { }`
- `fake_authenticator` (`WebAuthn::FakeClient` at `http://www.example.com`) for passkey ceremonies; a sign-in code is read back from `ActionMailer::Base.deliveries.last.text_part.decoded` (clear `deliveries` in a `before`)
- `Result::Mixin` is included in service, job and request specs: `Success(...)`, `Failure(...)`
- `ActiveJob::TestHelper` everywhere (`have_enqueued_job`, `have_enqueued_mail`, `perform_enqueued_jobs`)
- `travel_to` / `freeze_time` (reset after every example)
- WebMock blocks the network; a Gemini request outside a `:gemini_api` spec fails the suite (stubbed ones count too: tag HTTP-level Gemini specs `:gemini_api`)
- Onboarding request specs stub the engine: `allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload))`; `spec/requests/app/onboarding_spec.rb` has the payload shapes

## Patterns

### Model specs
```ruby
RSpec.describe Thing, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to define_enum_for(:status).with_values(draft: 0, active: 10) }
end
```

### Service specs
Success path, failure path (`result.error[:code]`), step halting (nothing created after a failure), `try_external` wrapping (`stub_request(...).to_return(status: 500)` → `:external_error`), side effects (`have_enqueued_job`, `change(Model, :count)`).

### Request specs (must render the page)
```ruby
RSpec.describe "Things", type: :request do
  let(:user) { create(:user) }
  before { sign_in_as(user) }

  it "lists the person's things" do
    mine = create(:thing, user: user)
    other = create(:thing)

    get app_things_path(locale: "en"), headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(mine.name).and include(I18n.t("app.things.index.title"))
    expect(response.body).not_to include(other.name)
  end

  it "is native only" do
    get app_things_path(locale: "en")
    expect(response).to redirect_to(root_path(locale: "en"))
  end
end
```
JSON endpoints: `post path, params: {...}, headers: native_headers, as: :json` and `response.parsed_body`. Turbo Stream responses: `headers: { "Accept" => "text/vnd.turbo-stream.html" }` and `response.media_type`.

### Job specs
`perform_now` with ids; a missing record does not raise; `have_enqueued_job(...).with(...)` for enqueuing; the switchboard hold (`create(:platform_switch, service: "jobs", paused: true)`).

### System specs (Cuprite)
`before { driven_by(:aluni_cuprite) }`, `visit root_path(locale: "en")`, `expect(page).to have_css(...)`, `expect_no_server_errors!`. `js_errors: true` makes any JavaScript exception fail the example.

### i18n and copy
`spec/i18n/` already enforces parity, string keys and the copy rules; new strings need both locales or the suite fails.

## Rules

- `let` by default, `let!` only when the record must exist before the action; `create` for persisted, `build` for in-memory
- Stub every outside call with WebMock; never touch real APIs
- Assert on rendered content, not only on status codes or redirects
- Test edge cases: nil, blank, boundaries, a second call (idempotency)
- `travel_to` for time, never stub `Time`
- Run: `mise exec -- bundle exec rspec <spec_file>`; the whole suite before claiming done
