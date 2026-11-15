namespace :encryption do
  # Models whose `encrypts` columns may still hold plaintext written before the
  # column was encrypted. Add a model name when you encrypt an existing column.
  ENCRYPTED_MODELS = %w[OnboardingSession].freeze

  desc "Encrypt legacy plaintext rows in place (idempotent), then set AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false"
  task backfill: :environment do
    failures = 0

    ENCRYPTED_MODELS.filter_map(&:safe_constantize).each do |model|
      encrypted = 0
      model.find_each do |record|
        record.encrypt # re-writes every encrypted attribute; already-encrypted values stay valid
        encrypted += 1
      rescue ActiveRecord::Encryption::Errors::Base, ActiveRecord::ActiveRecordError => e
        failures += 1
        puts "#{model.name} ##{record.id} failed: #{e.class}"
      end
      puts "#{model.name}: #{encrypted} rows encrypted"
    end

    if failures.positive?
      puts "#{failures} failed. Fix those rows and run the task again before setting " \
           "AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false."
      exit 1
    end

    puts "All rows encrypted. It is now safe to set AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false."
  end
end
