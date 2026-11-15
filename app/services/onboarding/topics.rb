module Onboarding
  # The ordered conversation plan from config/onboarding/topics.yml: topic
  # keys, the facts each one gathers and the guidance the system prompt
  # includes. Loaded once; validate! runs at boot (config/initializers/
  # onboarding.rb) so a typo fails the deploy, not the first message.
  class Topics
    PATH = Rails.root.join("config/onboarding/topics.yml")
    # Snapshot keys Onboarding::ProfileSnapshot#required_known? understands.
    REQUIRED_KEY = /\A(?:crops|profile\.\w+|farm\.\w+|field\.(?:soil\.)?\w+)\z/
    KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/

    class Invalid < StandardError; end

    class << self
      def keys = topics.map { |topic| topic["key"] }
      def first = keys.first
      def size = keys.size
      def include?(key) = keys.include?(key.to_s)
      def index(key) = keys.index(key.to_s)

      # The topic after key, nil after the last one (or for an unknown key).
      def next(key)
        position = index(key)
        position && keys[position + 1]
      end

      def guidance(key) = topic(key).fetch("guidance").strip
      def required(key) = Array(topic(key)["required"]).map(&:to_s)
      def rules = data.fetch("rules").strip
      def title_key(key) = "onboarding.topics.#{key}"

      def validate!
        raise Invalid, "#{PATH}: topics must be a non-empty list" unless topics.is_a?(Array) && topics.any?
        raise Invalid, "#{PATH}: rules must be a non-empty text" unless data["rules"].is_a?(String) && data["rules"].strip.present?

        seen = []
        topics.each do |topic|
          key = topic["key"].to_s
          raise Invalid, "#{PATH}: bad topic key #{key.inspect}" unless KEY_FORMAT.match?(key)
          raise Invalid, "#{PATH}: duplicate topic #{key}" if seen.include?(key)
          raise Invalid, "#{PATH}: topic #{key} has no guidance" unless topic["guidance"].is_a?(String) && topic["guidance"].strip.present?

          Array(topic["required"]).each do |fact|
            raise Invalid, "#{PATH}: topic #{key} requires unknown fact #{fact.inspect}" unless REQUIRED_KEY.match?(fact.to_s)
          end
          seen << key
        end
        true
      end

      def reload!
        @data = nil
      end

      private

      def topic(key)
        topics.find { |candidate| candidate["key"] == key.to_s } ||
          raise(ArgumentError, "unknown onboarding topic #{key.inspect}")
      end

      def topics = Array(data["topics"])

      def data
        @data ||= YAML.safe_load_file(PATH, aliases: false).tap do |loaded|
          raise Invalid, "#{PATH}: expected a mapping with rules and topics" unless loaded.is_a?(Hash)
        end
      end
    end
  end
end
