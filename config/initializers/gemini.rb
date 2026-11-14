# Gemini model ids and generation limits.
#
# Model ids change often (Google deprecates and reroutes old ids), so they live
# in ENV instead of code. Defaults are the current generally available Flash
# model; set GEMINI_PRO_MODEL to opt in to a Pro model.
Rails.application.config.x.gemini.flash_model = ENV["GEMINI_FLASH_MODEL"].presence || "gemini-3.8-flash"
Rails.application.config.x.gemini.pro_model = ENV["GEMINI_PRO_MODEL"].presence || "gemini-3.8-flash"
Rails.application.config.x.gemini.transcribe_model = ENV["GEMINI_TRANSCRIBE_MODEL"].presence || "gemini-3.8-flash"
Rails.application.config.x.gemini.chat_max_output_tokens =
  Integer(ENV["GEMINI_CHAT_MAX_OUTPUT_TOKENS"].presence || "2048")
