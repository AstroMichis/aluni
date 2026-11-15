# What a person chose on the welcome screen and in the accessibility controls.
# Language has its own cookie and column; the rest travels in the aluni_prefs
# cookie (any visitor) and in users.preferences (signed in). Every value is
# allowlisted, so a hand-edited cookie can never reach a view.
class Preferences
  COOKIE = :aluni_prefs
  OPTIONS = {
    "theme" => %w[dark light],
    "text_size" => %w[normal large larger],
    "motion" => %w[full reduce],
    "contrast" => %w[normal high]
  }.freeze
  FLAGS = %w[read_aloud seen_welcome].freeze
  DEFAULTS = {
    "theme" => "dark", "text_size" => "normal", "motion" => "full", "contrast" => "normal",
    "read_aloud" => false, "seen_welcome" => false
  }.freeze

  def self.from_cookie(raw)
    new(raw.present? ? JSON.parse(raw) : {})
  rescue JSON::ParserError, TypeError
    new
  end

  def self.sanitize(values)
    values = (values || {}).to_h.transform_keys(&:to_s)
    clean = {}
    OPTIONS.each { |key, allowed| clean[key] = values[key].to_s if allowed.include?(values[key].to_s) }
    FLAGS.each { |key| clean[key] = ActiveModel::Type::Boolean.new.cast(values[key]) == true unless values[key].nil? }
    clean
  end

  attr_reader :values

  def initialize(values = {})
    @values = DEFAULTS.merge(self.class.sanitize(values)).freeze
  end

  def [](key) = @values[key.to_s]
  def to_h = @values.dup
  def to_cookie = @values.to_json
  def merge(other) = self.class.new(@values.merge(self.class.sanitize(other)))
  def seen_welcome? = @values["seen_welcome"] == true
  def read_aloud? = @values["read_aloud"] == true

  # On <html>, so the first paint already has them (no flash).
  def html_attributes
    { "data-theme" => self["theme"], "data-text-size" => self["text_size"],
      "data-motion" => self["motion"], "data-contrast" => self["contrast"], "data-read-aloud" => read_aloud?.to_s }
  end

  # On <body data-controller="preferences">: Turbo keeps <html> across visits
  # and swaps the body, so the controller re-applies them every page.
  def stimulus_values
    { "data-preferences-theme-value" => self["theme"], "data-preferences-text-size-value" => self["text_size"],
      "data-preferences-motion-value" => self["motion"], "data-preferences-contrast-value" => self["contrast"],
      "data-preferences-read-aloud-value" => read_aloud?.to_s }
  end
end
