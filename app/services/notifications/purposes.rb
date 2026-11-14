# frozen_string_literal: true

require "yaml"

module Notifications
  # config/notification_purposes.yml, parsed and validated (boot fails on a bad
  # file). Re-read on every call in test so specs can swap it with `.with`.
  class Purposes
    class Invalid < StandardError; end
    class UnknownPurpose < StandardError; end

    PATH = Rails.root.join("config/notification_purposes.yml")
    AUDIENCES = %w[user].freeze
    CATEGORIES = %w[transactional marketing].freeze
    CHANNELS = %w[push web_push email].freeze

    Purpose = Struct.new(:key, :audience, :category, :group_key, :channels, :mailer, :push_key, keyword_init: true) do
      def transactional? = category == "transactional"
      def marketing? = category == "marketing"

      def mailer_class = mailer.split("#").first.constantize
      def mailer_action = mailer.split("#").last.to_sym

      def group_for(vars)
        return nil if group_key.blank?

        format(group_key, **vars.to_h.transform_keys(&:to_sym))
      rescue KeyError, ArgumentError
        nil
      end
    end

    class << self
      def current
        return @override if @override
        return load_file(PATH) if Rails.env.test?

        @current ||= load_file(PATH)
      end

      def fetch(key) = current.fetch(key)

      def load_file(path)
        new(YAML.safe_load(File.read(path)) || {}, source: path.to_s)
      end

      # Specs: `Notifications::Purposes.with("purposes" => { ... }) { ... }`.
      def with(data)
        previous = @override
        @override = new(data, source: "inline")
        yield @override
      ensure
        @override = previous
      end
    end

    attr_reader :source

    def initialize(data, source:)
      @source = source
      raw = data.is_a?(Hash) ? data["purposes"] : nil
      raise Invalid, "#{source}: `purposes` must be a map" unless raw.is_a?(Hash)

      @purposes = raw.to_h { |key, body| [ key.to_s, build(key.to_s, body || {}) ] }.freeze
    end

    def keys = @purposes.keys

    def fetch(key)
      @purposes.fetch(key.to_s) { raise UnknownPurpose, "#{source}: no notification purpose #{key.inspect}" }
    end

    private

    def build(key, body)
      audience = body["audience"].to_s
      category = body["category"].to_s
      channels = Array(body["channels"]).map(&:to_s)
      fail!(key, "audience must be one of #{AUDIENCES.join(', ')}") unless AUDIENCES.include?(audience)
      fail!(key, "category must be one of #{CATEGORIES.join(', ')}") unless CATEGORIES.include?(category)
      fail!(key, "channels must be a non-empty list of #{CHANNELS.join(', ')}") if channels.empty? || (channels - CHANNELS).any?
      fail!(key, "channel email needs `mailer: Mailer#action`") if channels.include?("email") && !body["mailer"].to_s.match?(/\A[A-Z][\w:]*#[a-z_]+\z/)
      fail!(key, "channels push and web_push need `push_key`") if (channels & %w[push web_push]).any? && body["push_key"].blank?

      Purpose.new(key: key, audience: audience, category: category, group_key: body["group_key"].presence,
                  channels: channels.freeze, mailer: body["mailer"].presence, push_key: body["push_key"].presence).freeze
    end

    def fail!(key, message) = raise(Invalid, "#{source}: purpose #{key}: #{message}")
  end
end
