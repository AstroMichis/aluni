# Production must not boot without Active Record encryption keys (see
# lib/active_record_encryption_check.rb). Skipped during the Docker
# assets:precompile step, which runs with SECRET_KEY_BASE_DUMMY.
Rails.application.config.after_initialize do
  ActiveRecordEncryptionCheck.verify! if ActiveRecordEncryptionCheck.enforce?
end
