# Limits for the onboarding chat (app/services/onboarding/, docs/ONBOARDING.md).
# Read through Rails.configuration.x.onboarding, never from ENV in app code.
Rails.application.config.x.onboarding.max_turns = 40            # transcript turns kept on the row
Rails.application.config.x.onboarding.context_turns = 20        # turns sent to Gemini each reply
Rails.application.config.x.onboarding.strike_limit = 3          # unsafe messages before a block
Rails.application.config.x.onboarding.block_ttl = 24.hours
Rails.application.config.x.onboarding.gemini_timeout = 20       # seconds, per Gemini call and classifier join
Rails.application.config.x.onboarding.max_output_tokens = 1024  # the reply draft
Rails.application.config.x.onboarding.classifier_max_tokens = 128

# Fail at boot, not at the first message, when config/onboarding/topics.yml is
# malformed or names a required fact the snapshot cannot read.
Rails.application.config.after_initialize do
  Onboarding::Topics.validate!
end
