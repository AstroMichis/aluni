require "rails_helper"

# Every literal t() key in the menu sections' views (absolute or lazy) exists
# in both locales, so a renamed or dropped key fails here, not on screen.
RSpec.describe "Menu section copy" do
  VIEWS = Dir[Rails.root.join("app/views/app/{fields,farms,crops,weather,team,reports,home,rotations,field_layouts}/**/*.erb")].freeze

  def scope_for(file)
    file.delete_prefix("#{Rails.root}/app/views/").sub(/\.html\.erb\z/, "").sub(%r{/_?([^/]+)\z}) { "/#{$1}" }.tr("/", ".")
  end

  it "has every key in English and Spanish" do
    missing = VIEWS.flat_map do |file|
      File.read(file).scan(/\bt\("([^"#]+)"/).flatten.flat_map do |key|
        full = key.start_with?(".") ? "#{scope_for(file)}#{key}" : key
        %i[en es].reject { |l| I18n.exists?(full, l) || I18n.exists?("#{full}.one", l) }.map { |l| "#{l} #{full} (#{File.basename(file)})" }
      end
    end
    expect(missing).to be_empty
  end
end
