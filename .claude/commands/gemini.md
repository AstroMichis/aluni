# /gemini -- Assistant Feature Builder

You are building a Gemini-backed feature for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/INTEGRATIONS.md`, Gemini section
2. Read `app/services/gemini/client.rb` (the HTTP client, retries, `last_error`) and `app/services/gemini/language_prompt.rb`
3. Read `spec/services/gemini/client_spec.rb` (how calls are stubbed) and `spec/support/external_apis.rb` (why unstubbed calls fail the suite)
4. Read `config/initializers/gemini.rb` and `config/initializers/rack_attack.rb`

## Gemini::Client

```ruby
client = Gemini::Client.new(model: :flash)          # :flash | :pro | :transcribe (config.x.gemini, ENV GEMINI_*_MODEL); timeout: seconds overrides the 30 s read timeout
# Backend from ENV GEMINI_BACKEND: api_key (credentials gemini.api_key) or vertex (GOOGLE_CLOUD_PROJECT, token from the VM's service account; production). Same bodies either way.

text = client.generate(prompt,
  system_instruction: Gemini::LanguagePrompt.lock(I18n.locale) + persona,
  images: [ { mime_type: "image/jpeg", base64_data: data } ],
  response_schema: SCHEMA,                           # structured JSON output
  max_tokens: 1024)

text = client.chat(messages: [ { role: "user", parts: [ { text: "Hi" } ] }, { role: "model", parts: [ { text: "Hello" } ] } ],
                   system_instruction: persona)

client.last_error  # { type:, status:, message:, retry_after: } when the call returned nil
```

- `generate` is single turn (temperature 0.3); `chat` is multi turn (0.4). Thinking is kept minimal per model family automatically.
- The client calls `Platform::Switchboard.guard!(:gemini)` before every request: a paused service raises `Platform::ServicePaused`, which `ApplicationController` turns into a calm notice and `ApplicationJob` into a 15-minute hold.
- Retries: 429/5xx/network/empty up to three times inside a 6 s budget; then `nil` and `last_error`. **Always handle nil.**

## Service shape

```ruby
module Assistant
  class AnswerService < ApplicationService
    SCHEMA = { type: "object", properties: { reply: { type: "string" }, done: { type: "boolean" } }, required: %w[reply done] }.freeze

    def initialize(messages:, locale:)
      @messages = messages
      @locale = locale
    end

    def call
      parsed = step ask
      Success(parsed)
    end

    private

    def ask
      try_external(Faraday::Error, JSON::ParserError) do
        text = Gemini::Client.new.generate(prompt, system_instruction: system, response_schema: SCHEMA)
        raise JSON::ParserError, "no answer" if text.nil?
        JSON.parse(text)
      end
    end

    def system = Gemini::LanguagePrompt.lock(@locale) + PERSONA
  end
end
```

Run it from a job on the `gemini` queue (`queue_as :gemini`) unless a person is waiting on the answer: the onboarding chat (`Onboarding::ReplyService`, `docs/ONBOARDING.md`) calls Gemini inline by product decision, with a 20 s timeout, the classifier in a thread, and an in-character continuation line whenever the call fails or the service is paused.

## Rules

- Structured output through `response_schema`; rescue `JSON::ParserError`; never show a raw processing error, retry or continue in character
- Prompts: set the persona, the language lock, the boundaries and the output format; never mention "AI", "model" or "bot" in text a person reads unless the product decides otherwise
- Multi-turn state: encrypted at rest (the onboarding keeps its transcript in `onboarding_sessions.transcript`, an `encrypts` column, so a refresh resumes), PII redacted before storage (`Onboarding::Redactor`); keep pending state for follow-up turns and never treat a follow-up as a fresh extraction
- Abuse: an intent classifier with rate limits and a strike/block system before any person-facing assistant ships
- Rack::Attack: throttle the assistant's endpoints per IP (20/min, 150/hour) in `config/initializers/rack_attack.rb` (`RACK_ATTACK_ASSISTANT_PATH` covers `/app/onboarding/*`)
- Cost: Flash for text, Pro only with images; low temperature for extraction; log token-heavy prompts
- The operator can pause Gemini at any time (`platform:pause[gemini]`); the product must degrade gracefully

## Testing

- `spec/services/gemini/` is tagged `:gemini_api`; other specs must stub with WebMock (`stub_request(:post, /generativelanguage\.googleapis\.com/)`) and are failed by `spec/support/external_apis.rb` if a request leaks
- Cover: success, 429 then success, exhaustion (nil + `last_error`), malformed JSON, the paused switch
- Stub `Rails.application.credentials.dig(:gemini, :api_key)` in specs (the test backend is `api_key`); the key is never in the repo. Vertex has its own context in `spec/services/gemini/client_spec.rb` (metadata-server token stubbed with WebMock)
- Run: `mise exec -- bundle exec rspec spec/services/gemini`
