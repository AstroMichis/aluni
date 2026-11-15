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

# Backend: "api_key" (Gemini Developer API, key in credentials gemini.api_key)
# or "vertex" (Vertex AI, no key: the VM's attached service account, token from
# the GCE metadata server). Vertex needs GOOGLE_CLOUD_PROJECT; location defaults
# to "global".
Rails.application.config.x.gemini.backend = ENV["GEMINI_BACKEND"].presence || "api_key"
Rails.application.config.x.gemini.vertex_project = ENV["GOOGLE_CLOUD_PROJECT"].presence
Rails.application.config.x.gemini.vertex_location = ENV["GOOGLE_CLOUD_LOCATION"].presence || "global"

# Daily ceiling on Gemini requests for the whole app (Gemini::DailyCap). Vertex
# has no per-project cap for the Gemini 3 models (dynamic shared quota), so the
# app enforces one: past it, the gemini switch pauses itself until an operator
# resumes it. 0 turns the cap off; tests default to off.
Rails.application.config.x.gemini.daily_cap =
  Integer(ENV["GEMINI_DAILY_CAP"].presence || (Rails.env.test? ? "0" : "2000"))
