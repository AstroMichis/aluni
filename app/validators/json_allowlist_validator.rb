# Keeps the jsonb columns the onboarding chat fills inside their allowlists.
#
#   validates :goals, json_allowlist: { values: GOALS }                 # an array of slugs
#   validates :soil,  json_allowlist: { keys: SOIL, extra_keys: %w[ph] } # a hash: key => allowed value(s)
#
# Array values inside a hash are checked element by element; keys listed in
# extra_keys are accepted with any value (numbers, booleans, free text).
class JsonAllowlistValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if options[:values]
      validate_array(record, attribute, value, options[:values])
    elsif options[:keys]
      validate_hash(record, attribute, value, options[:keys], Array(options[:extra_keys]).map(&:to_s))
    else
      raise ArgumentError, "json_allowlist needs :values or :keys"
    end
  end

  private

  def validate_array(record, attribute, value, allowed)
    return record.errors.add(attribute, :invalid) unless value.is_a?(Array)

    strings = value.map(&:to_s)
    record.errors.add(attribute, :inclusion) if (strings - allowed).any? || strings.uniq.size != strings.size
  end

  def validate_hash(record, attribute, value, allowed, extra)
    return record.errors.add(attribute, :invalid) unless value.is_a?(Hash)

    value.each do |key, entry|
      key = key.to_s
      next if extra.include?(key)
      return record.errors.add(attribute, :inclusion) unless allowed.key?(key)

      permitted = allowed[key]
      bad = entry.is_a?(Array) ? (entry.map(&:to_s) - permitted).any? : !permitted.include?(entry.to_s)
      return record.errors.add(attribute, :inclusion) if bad
    end
  end
end
