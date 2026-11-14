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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_205805) do
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
  add_foreign_key "passkeys", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "web_push_subscriptions", "users"
end
