# Operator switches from the command line (and from GitHub Actions through
# `kamal app exec`, .github/workflows/platform-switch.yml).
#
#   bin/rails "platform:pause[gemini,quota]"   # pause Gemini with a reason
#   bin/rails "platform:resume[gemini]"
#   bin/rails platform:status
#   bin/rails platform:bootstrap                # first deploy: pause what costs money
namespace :platform do
  # Services paused on first deploy; resumed one by one as each is set up.
  bootstrap_paused = %w[cron gemini mail push].freeze

  toggle = lambda do |service, paused, reason|
    result = Platform::ToggleService.call(service: service, paused: paused, reason: reason.presence || "rake")
    abort("platform: #{result.error[:message]}") if result.failure?
    puts "#{paused ? 'paused ' : 'resumed'} #{service}"
  end

  desc "Pause a service: platform:pause[service,reason]"
  task :pause, %i[service reason] => :environment do |_t, args|
    toggle.call(args.fetch(:service), true, args[:reason])
  end

  desc "Resume a service: platform:resume[service]"
  task :resume, %i[service] => :environment do |_t, args|
    toggle.call(args.fetch(:service), false, nil)
  end

  desc "Pause every service"
  task pause_all: :environment do
    PlatformSwitch::SERVICES.each { |service| toggle.call(service, true, "pause_all") }
  end

  desc "Resume every paused service"
  task resume_all: :environment do
    PlatformSwitch.paused.find_each { |s| toggle.call(s.service, false, nil) }
  end

  desc "First deploy: pause cron and every paid outside service, keep jobs running"
  task bootstrap: :environment do
    bootstrap_paused.each { |service| toggle.call(service, true, "bootstrap") }
  end

  desc "Show paused services"
  task status: :environment do
    puts "PLATFORM_PAUSE_ALL=1 is set: everything is paused" if Platform::Switchboard.pause_all_env?
    paused = PlatformSwitch.paused.order(:service)
    puts "Nothing paused." if paused.empty?
    paused.each { |s| puts format("%-10s %-14s %s", s.service, s.paused_by, s.reason) }
  end
end
