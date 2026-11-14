require "rails_helper"

# Copy rules the suite enforces instead of a linter: every string goes through
# t(), the brand name is one key, no em dashes anywhere a person reads.
RSpec.describe "Copy rules" do
  VIEW_FILES = Dir[Rails.root.join("app/views/**/*.html.erb")].freeze

  def without_erb_comments(source)
    source.gsub(/<%#.*?%>/m, "").gsub(%r{<style.*?</style>}m, "").gsub(%r{<script.*?</script>}m, "")
  end

  it "keeps the brand name in app_name" do
    expect(I18n.t("app_name", locale: :en)).to eq("Aluni")
    expect(I18n.t("app_name", locale: :es)).to eq("Aluni")
  end

  it "never hardcodes the brand name in a view" do
    offenders = VIEW_FILES.select { |f| without_erb_comments(File.read(f)).match?(/\bAluni\b/) }
    expect(offenders.map { |f| f.sub("#{Rails.root}/", "") }).to be_empty
  end

  it "has no em dashes in views" do
    offenders = VIEW_FILES.select { |f| without_erb_comments(File.read(f)).include?("—") }
    expect(offenders).to be_empty
  end

  it "has no visible text outside t() in views" do
    # Text nodes between tags that contain letters and are not ERB output.
    offenders = VIEW_FILES.flat_map do |file|
      html = without_erb_comments(File.read(file)).gsub(/<%.*?%>/m, "").gsub(/<(?:[^>"']|"[^"]*"|'[^']*')*>/, "\n")
      html.lines.map(&:strip).select { |line| line.match?(/\p{L}{3,}/) && !line.match?(/\A&\w+;\z/) }.map { |line| "#{file.sub("#{Rails.root}/", '')}: #{line}" }
    end
    expect(offenders).to be_empty
  end
end
