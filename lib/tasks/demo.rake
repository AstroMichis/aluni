# frozen_string_literal: true

namespace :demo do
  desc "Load a sample farm into an account that signed up: USER_ID=.. PRESET=nebraska|chile [FORCE=1]"
  task farm: :environment do
    user = User.find_by(id: ENV.fetch("USER_ID") { abort "USER_ID is required (the account must sign up with a passkey first)" })
    preset = ENV.fetch("PRESET") { abort "PRESET is one of: #{Demo::FarmService.presets.keys.join(', ')}" }
    result = Demo::FarmService.call(user: user, preset: preset, force: ENV["FORCE"] == "1")
    case result
    in Result::Success(field)
      puts "#{field.farm.name} / #{field.name} (field #{field.id}) for user #{user.id}. Waiting for the data at the pin..."
      # The worker fetches it (Field#after_commit enqueued the job); POWER, GAEZ and the NDVI take a minute or two.
      deadline = 4.minutes.from_now
      sleep 5 until field.observations.reload.where(source: %w[nasa_power gaez vegetation]).count == 3 || Time.current > deadline
      puts field.observations.reload.order(:source).pluck(:source, :status).map { |s, st| "  #{s}: #{st}" }
      puts "Missing sources: is the worker running? Retry with \"Refresh data\" on the field." if field.observations.count < 3
    in Result::Failure(code: :has_farms, count:)
      abort "User #{user.id} has #{count} other farm(s). Use a dedicated demo account, or FORCE=1."
    in Result::Failure(code:, **rest)
      abort "Failed: #{code} #{rest[:messages]&.join(', ')}"
    end
  end
end
