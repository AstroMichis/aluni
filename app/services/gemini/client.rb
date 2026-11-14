module Gemini
  # Thin client over the Gemini REST API. Callers always handle nil (every
  # failure path returns nil and leaves the reason in #last_error) and rescue
  # JSON::ParserError when they asked for structured output.
  class Client
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

    # Fallbacks when config/initializers/gemini.rb (ENV GEMINI_FLASH_MODEL /
    # GEMINI_PRO_MODEL / GEMINI_TRANSCRIBE_MODEL) leaves a tier blank.
    DEFAULT_MODELS = { flash: "gemini-3.8-flash", pro: "gemini-3.8-flash", transcribe: "gemini-3.8-flash" }.freeze
    DEFAULT_CHAT_MAX_OUTPUT_TOKENS = 2048

    RETRY_BACKOFFS = [ 0.5, 1.5, 3.0 ].freeze
    RETRY_BUDGET = 6.0
    RETRY_AFTER_CAP = 5.0

    attr_reader :last_error

    def self.models
      config = Rails.configuration.x.gemini
      {
        flash: config.flash_model.presence || DEFAULT_MODELS[:flash],
        pro: config.pro_model.presence || DEFAULT_MODELS[:pro],
        transcribe: config.transcribe_model.presence || DEFAULT_MODELS[:transcribe]
      }
    end

    # Thinking tokens count against maxOutputTokens, so we keep thinking as low
    # as each model family allows. Gemini 3 rejects thinkingBudget 0 and the
    # "minimal" level, 2.5 Pro cannot disable thinking (minimum budget 128), and
    # only 2.5 Flash / Flash-Lite accept thinkingBudget 0.
    def self.thinking_config_for(model_id)
      case model_id.to_s
      when /\Agemini-3/ then { thinkingLevel: "low" }
      when /\Agemini-2\.5-flash/ then { thinkingBudget: 0 }
      when /\Agemini-2\.5-pro/ then { thinkingBudget: 128 }
      end
    end

    def initialize(model: :flash)
      @model = self.class.models.fetch(model)
      @api_key = Rails.application.credentials.dig(:gemini, :api_key)
      @last_error = nil
    end

    # Single turn. Structured JSON when response_schema is given.
    def generate(prompt, system_instruction: nil, images: [], response_schema: nil, max_tokens: 1024)
      @last_error = nil
      body = build_body(prompt, system_instruction, images, response_schema, max_tokens)
      path = "models/#{@model}:generateContent"

      with_retries do
        post_and_extract(path, body, expect_schema: !response_schema.nil?)
      end
    end

    # Multi turn. messages follow Gemini's contents format:
    # [{ role: "user" | "model", parts: [{ text: "..." }] }]
    def chat(messages:, system_instruction: nil)
      @last_error = nil
      body = {
        contents: messages,
        generationConfig: { temperature: 0.4, maxOutputTokens: chat_max_output_tokens }
      }
      apply_thinking_config(body)
      body[:systemInstruction] = { parts: [ { text: system_instruction } ] } if system_instruction
      path = "models/#{@model}:generateContent"

      with_retries do
        post_and_extract(path, body, expect_schema: false)
      end
    end

    private

    def with_retries
      sleep_used = 0.0

      (RETRY_BACKOFFS.size + 1).times do |attempt|
        text = yield
        if text
          @last_error = nil
          return text
        end

        err = @last_error
        return nil unless err && retryable?(err[:type])
        break if attempt >= RETRY_BACKOFFS.size

        wait = retry_delay(attempt, err)
        if sleep_used + wait > RETRY_BUDGET
          log_retry_giveup(err, attempt + 1, sleep_used)
          return nil
        end

        log_retry(err, attempt + 1, wait)
        sleep(wait)
        sleep_used += wait
      end

      log_failure(@last_error, RETRY_BACKOFFS.size + 1)
      nil
    end

    def retryable?(type)
      %i[rate_limited service_unavailable network_error empty_response].include?(type)
    end

    def retry_delay(attempt, err)
      base = RETRY_BACKOFFS[attempt]
      if err[:type] == :rate_limited && err[:retry_after]
        base = [ err[:retry_after], RETRY_AFTER_CAP ].min
      end
      jitter = rand * 0.2
      base + jitter
    end

    def post_and_extract(path, body, expect_schema:)
      Platform::Switchboard.guard!(:gemini)
      response = connection.post(path, body.to_json)

      unless response.success?
        @last_error = classify_http_error(response)
        return nil
      end

      text = response.body.dig("candidates", 0, "content", "parts", 0, "text")
      if text.nil? || text.empty?
        @last_error = {
          type: :empty_response,
          status: response.status,
          message: "Gemini returned no text in candidates[0].content.parts[0].text",
          retry_after: nil
        }
        return nil
      end

      expect_schema ? fix_unicode_escapes(text) : text
    rescue Faraday::TimeoutError => e
      @last_error = { type: :network_error, status: nil, message: "Timeout: #{e.message}", retry_after: nil }
      nil
    rescue Faraday::ConnectionFailed => e
      @last_error = { type: :network_error, status: nil, message: "Connection failed: #{e.message}", retry_after: nil }
      nil
    rescue Faraday::Error => e
      @last_error = { type: :network_error, status: nil, message: e.message, retry_after: nil }
      nil
    end

    def classify_http_error(response)
      status = response.status
      message = response.body.is_a?(Hash) ? response.body.dig("error", "message").to_s : response.body.to_s

      type =
        case status
        when 429 then :rate_limited
        when 500, 502, 503, 504 then :service_unavailable
        else :api_error
        end

      retry_after = type == :rate_limited ? parse_retry_after(message) : nil

      { type: type, status: status, message: message[0, 500], retry_after: retry_after }
    end

    def parse_retry_after(message)
      match = message.match(/retry in ([\d.]+)s/i)
      return nil unless match

      match[1].to_f
    end

    def log_retry(err, attempt, wait)
      Rails.logger.warn(
        "Gemini retry: model=#{@model} attempt=#{attempt} type=#{err[:type]} status=#{err[:status]} " \
        "retry_after=#{err[:retry_after]} wait=#{wait.round(2)}s"
      )
    end

    def log_retry_giveup(err, attempts, sleep_used)
      Rails.logger.error(
        "Gemini gave up (budget exhausted): model=#{@model} attempts=#{attempts} " \
        "sleep_used=#{sleep_used.round(2)}s type=#{err[:type]} status=#{err[:status]} " \
        "retry_after=#{err[:retry_after]} message=#{err[:message]}"
      )
    end

    def log_failure(err, attempts)
      return unless err

      Rails.logger.error(
        "Gemini error: model=#{@model} attempts=#{attempts} type=#{err[:type]} " \
        "status=#{err[:status]} retry_after=#{err[:retry_after]} message=#{err[:message]}"
      )
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.headers["x-goog-api-key"] = @api_key
        f.request :retry, max: 2, interval: 0.5
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end

    # Gemini's structured JSON output (responseSchema) sometimes strips the \u prefix
    # from Unicode escapes, producing "importaci\n00f3n" instead of "importación".
    # This fixes the hex codes AND removes spurious newlines around them.
    def fix_unicode_escapes(text)
      return text if text.nil?

      text.gsub(/\n?00([89a-f][0-9a-f])\n?/i) do
        [ $1.to_i(16) ].pack("U")
      end
    end

    def build_body(prompt, system_instruction, images, response_schema, max_tokens)
      parts = [ { text: prompt } ]
      images.each do |img|
        parts << { inline_data: { mime_type: img[:mime_type], data: img[:base64_data] } }
      end

      body = {
        contents: [ { role: "user", parts: parts } ],
        generationConfig: { temperature: 0.3, maxOutputTokens: max_tokens }
      }

      apply_thinking_config(body)
      body[:systemInstruction] = { parts: [ { text: system_instruction } ] } if system_instruction

      if response_schema
        body[:generationConfig][:responseMimeType] = "application/json"
        body[:generationConfig][:responseSchema] = response_schema
      end

      body
    end

    def apply_thinking_config(body)
      thinking = self.class.thinking_config_for(@model)
      body[:generationConfig][:thinkingConfig] = thinking if thinking
    end

    def chat_max_output_tokens
      Rails.configuration.x.gemini.chat_max_output_tokens.presence || DEFAULT_CHAT_MAX_OUTPUT_TOKENS
    end
  end
end
