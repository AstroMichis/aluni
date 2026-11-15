# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_15_041533) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_push_native_devices", force: :cascade do |t|
    t.string "name"
    t.string "platform", null: false
    t.string "token", null: false
    t.string "owner_type"
    t.bigint "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_action_push_native_devices_on_owner"
    t.index ["platform", "token"], name: "index_action_push_native_devices_on_platform_and_token", unique: true
  end

  create_table "device_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.integer "platform", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token", "platform"], name: "index_device_tokens_on_token_and_platform", unique: true
    t.index ["user_id"], name: "index_device_tokens_on_user_id"
  end

  create_table "farmer_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "role", default: 0, null: false
    t.integer "experience", default: 0, null: false
    t.integer "team", default: 0, null: false
    t.integer "team_size"
    t.integer "units", default: 0, null: false
    t.integer "land_tenure", default: 0, null: false
    t.integer "budget_level", default: 0, null: false
    t.integer "risk_tolerance", default: 0, null: false
    t.integer "segment", default: 0, null: false
    t.jsonb "goals", default: [], null: false
    t.jsonb "equipment", default: [], null: false
    t.jsonb "livestock", default: [], null: false
    t.jsonb "market_channels", default: [], null: false
    t.jsonb "practices", default: [], null: false
    t.jsonb "notification_preferences", default: {}, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_farmer_profiles_on_user_id", unique: true
  end

  create_table "farms", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", default: "", null: false
    t.string "country_code", limit: 2
    t.string "admin_area"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_farms_on_user_id"
  end

  create_table "field_crops", force: :cascade do |t|
    t.bigint "field_id", null: false
    t.string "crop_name", null: false
    t.string "scientific_name"
    t.string "crop_key"
    t.integer "season_year", null: false
    t.integer "planting_month"
    t.integer "harvest_month"
    t.integer "role", default: 0, null: false
    t.integer "source", default: 0, null: false
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["field_id", "season_year", "role"], name: "index_field_crops_on_field_id_and_season_year_and_role", unique: true
    t.index ["field_id"], name: "index_field_crops_on_field_id"
  end

  create_table "fields", force: :cascade do |t|
    t.bigint "farm_id", null: false
    t.string "name", default: "", null: false
    t.integer "position", default: 0, null: false
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.integer "location_confidence", default: 0, null: false
    t.integer "location_source", default: 0, null: false
    t.string "place_label"
    t.jsonb "boundary", default: {}, null: false
    t.decimal "area", precision: 10, scale: 2
    t.integer "area_unit", default: 0, null: false
    t.integer "irrigation", default: 0, null: false
    t.integer "water_source", default: 0, null: false
    t.integer "cropping_intensity", default: 0, null: false
    t.jsonb "soil", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["farm_id", "position"], name: "index_fields_on_farm_id_and_position"
    t.index ["farm_id"], name: "index_fields_on_farm_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.string "purpose", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "idempotency_key", null: false
    t.integer "status", default: 0, null: false
    t.string "channel"
    t.datetime "sent_at"
    t.string "provider_message_id"
    t.jsonb "attempts", default: [], null: false
    t.string "failed_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_notification_deliveries_on_idempotency_key", unique: true
    t.index ["purpose", "created_at"], name: "index_notification_deliveries_on_purpose_and_created_at"
    t.index ["recipient_type", "recipient_id"], name: "index_notification_deliveries_on_recipient"
  end

  create_table "onboarding_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "topic", default: "welcome", null: false
    t.integer "status", default: 0, null: false
    t.datetime "completed_at"
    t.text "transcript"
    t.jsonb "proposal", default: {}, null: false
    t.text "pending_message"
    t.integer "fallbacks_count", default: 0, null: false
    t.integer "turns_count", default: 0, null: false
    t.integer "strikes", default: 0, null: false
    t.datetime "blocked_until"
    t.string "language"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_onboarding_sessions_on_user_id", unique: true
  end

  create_table "passkeys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "nickname", default: "", null: false
    t.string "transports", default: [], null: false, array: true
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
    t.index ["user_id"], name: "index_passkeys_on_user_id"
  end

  create_table "platform_switches", force: :cascade do |t|
    t.string "service", null: false
    t.boolean "paused", default: false, null: false
    t.string "paused_by"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service"], name: "index_platform_switches_on_service", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "webauthn_id", null: false
    t.string "display_name", null: false
    t.string "email_address"
    t.string "locale", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true, where: "(email_address IS NOT NULL)"
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  create_table "web_push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.string "user_agent"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "endpoint"], name: "index_web_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  add_foreign_key "device_tokens", "users"
  add_foreign_key "farmer_profiles", "users"
  add_foreign_key "farms", "users"
  add_foreign_key "field_crops", "fields"
  add_foreign_key "fields", "farms"
  add_foreign_key "onboarding_sessions", "users"
  add_foreign_key "passkeys", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "web_push_subscriptions", "users"
end
