require "rails_helper"

# YAML 1.1 parses unquoted on/off/yes/no/true/false/null keys as booleans or
# nil; such a key silently disappears from I18n. Quote them or rename them.
RSpec.describe "Locale files" do
  def non_string_keys(node, path = [], out = [])
    return out unless node.is_a?(Hash)

    node.each do |key, value|
      out << (path + [ key.inspect ]).join(".") unless key.is_a?(String)
      non_string_keys(value, path + [ key.to_s ], out)
    end
    out
  end

  it "contain only string keys" do
    Dir[Rails.root.join("config/locales/**/*.yml")].each do |file|
      offenders = non_string_keys(YAML.load_file(file))
      expect(offenders).to be_empty, "#{file}: #{offenders.join(', ')}"
    end
  end
end
