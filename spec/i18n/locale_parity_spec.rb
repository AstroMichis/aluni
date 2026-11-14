require "rails_helper"

# Every key present in one locale must exist in the other. Plural branches and
# array indexes collapse so a different pluralisation shape is not a diff.
RSpec.describe "Locale parity" do
  LOCALES = I18n.available_locales.map(&:to_s).freeze
  PLURAL_KEYS = %w[zero one two few many other].freeze

  def locale_tree(locale)
    Dir[Rails.root.join("config/locales/#{locale}/**/*.yml")].sort.each_with_object({}) do |file, tree|
      data = YAML.load_file(file)
      tree.deep_merge!(data.fetch(locale) { raise "#{file} does not start with the #{locale} key" })
    end
  end

  def flatten(node, prefix = nil, out = [])
    case node
    when Hash
      if node.keys.map(&:to_s).all? { |k| PLURAL_KEYS.include?(k) }
        out << prefix
      else
        node.each { |k, v| flatten(v, [ prefix, k ].compact.join("."), out) }
      end
    when Array
      out << prefix
    else
      out << prefix
    end
    out
  end

  it "has the same keys in every locale" do
    trees = LOCALES.index_with { |locale| flatten(locale_tree(locale)).to_set }
    base = trees.fetch(I18n.default_locale.to_s)

    trees.each do |locale, keys|
      next if locale == I18n.default_locale.to_s

      expect(keys - base).to be_empty, "keys only in #{locale}: #{(keys - base).to_a.sort.first(20).join(', ')}"
      expect(base - keys).to be_empty, "keys missing from #{locale}: #{(base - keys).to_a.sort.first(20).join(', ')}"
    end
  end

  it "uses no em dashes in copy" do
    offenders = Dir[Rails.root.join("config/locales/**/*.yml")].select { |f| File.read(f).include?("—") }
    expect(offenders).to be_empty
  end
end
