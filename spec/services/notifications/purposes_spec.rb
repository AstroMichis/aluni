require "rails_helper"

RSpec.describe Notifications::Purposes do
  it "loads the committed registry" do
    expect(described_class.load_file(described_class::PATH).keys).to eq([])
  end

  it "builds a purpose with its channels in order" do
    described_class.with("purposes" => { "welcome" => { "audience" => "user", "category" => "transactional",
                                                       "channels" => %w[push email], "mailer" => "NotificationMailer#generic", "push_key" => "welcome" } }) do |registry|
      purpose = registry.fetch(:welcome)
      expect(purpose.channels).to eq(%w[push email])
      expect(purpose.mailer_class).to eq(NotificationMailer)
      expect(purpose.mailer_action).to eq(:generic)
      expect(purpose).to be_transactional
    end
  end

  it "rejects an unknown channel" do
    expect { described_class.new({ "purposes" => { "x" => { "audience" => "user", "category" => "transactional", "channels" => %w[fax] } } }, source: "spec") }
      .to raise_error(described_class::Invalid, /channels must be/)
  end

  it "requires a mailer for the email channel" do
    expect { described_class.new({ "purposes" => { "x" => { "audience" => "user", "category" => "transactional", "channels" => %w[email] } } }, source: "spec") }
      .to raise_error(described_class::Invalid, /mailer/)
  end

  it "requires a push_key for push channels" do
    expect { described_class.new({ "purposes" => { "x" => { "audience" => "user", "category" => "transactional", "channels" => %w[web_push] } } }, source: "spec") }
      .to raise_error(described_class::Invalid, /push_key/)
  end

  it "raises for an unknown purpose" do
    expect { described_class.current.fetch(:nope) }.to raise_error(described_class::UnknownPurpose)
  end
end
