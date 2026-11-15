require "rails_helper"

# Every Turbo Stream the onboarding renders must aim at an element the page
# actually has: a stream targeting an id nobody renders is silently dropped by
# Turbo, which is the kind of bug no request spec notices.
RSpec.describe "Onboarding Turbo Stream targets", type: :view do
  let(:views_dir) { Rails.root.join("app/views/app/onboarding") }
  let(:streams) { Dir[views_dir.join("*.turbo_stream.erb")].sort }
  let(:page_sources) { Dir[views_dir.join("{show,_*}.html.erb")].map { |file| File.read(file) } }

  def ids_in(source)
    source.scan(/\bid="([A-Za-z][\w-]*)"/).flatten
  end

  def targets_in(source)
    source.scan(/turbo_stream\.(?:append|prepend|replace|update|remove|before|after)\s+"([\w-]+)"/).flatten
  end

  it "has stream templates for every chat action" do
    expect(streams.map { |f| File.basename(f, ".turbo_stream.erb") }).to contain_exactly("confirm", "discard", "message", "notice", "skip")
  end

  it "aims every stream at an id rendered by show or one of its partials" do
    rendered = page_sources.flat_map { |source| ids_in(source) }.to_set
    expect(rendered).to include("onboarding-messages", "onboarding-confirm", "onboarding-progress", "onboarding-location-tools", "onboarding-notice", "profile-preview")

    streams.each do |file|
      targets = targets_in(File.read(file))
      expect(targets).not_to be_empty, "#{File.basename(file)} renders no turbo_stream action"
      targets.each do |id|
        expect(rendered).to include(id), "#{File.basename(file)} targets ##{id}, which no page template renders"
      end
    end
  end

  it "replaces only elements whose partial carries the id itself" do
    streams.each do |file|
      File.read(file).scan(/turbo_stream\.replace\s+"([\w-]+)"/).flatten.each do |id|
        partials = Dir[views_dir.join("_*.html.erb")].select { |partial| ids_in(File.read(partial)).include?(id) }
        expect(partials).not_to be_empty, "#{File.basename(file)} replaces ##{id} but no partial renders that id as its root"
      end
    end
  end
end
