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

ActiveRecord::Schema[8.1].define(version: 2026_11_12_043149) do
  create_table "feeds", force: :cascade do |t|
    t.string "url", null: false
    t.string "provider", null: false
    t.string "name"
    t.string "site_url"
    t.datetime "last_polled_at"
    t.datetime "last_success_at"
    t.datetime "next_poll_at"
    t.text "last_error"
    t.integer "consecutive_failures", default: 0, null: false
    t.string "etag"
    t.string "last_modified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_poll_at"], name: "index_feeds_on_next_poll_at"
    t.index ["url"], name: "index_feeds_on_url", unique: true
  end

  create_table "incidents", force: :cascade do |t|
    t.integer "feed_id", null: false
    t.string "external_id", null: false
    t.string "title", null: false
    t.string "impact", default: "unknown", null: false
    t.string "status"
    t.string "url"
    t.datetime "started_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id", "external_id"], name: "index_incidents_on_feed_id_and_external_id", unique: true
    t.index ["feed_id", "started_at"], name: "index_incidents_on_feed_id_and_started_at"
    t.index ["feed_id"], name: "index_incidents_on_feed_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "default_min_severity", default: "minor", null: false
    t.string "no_incident_display", default: "infinity", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "incidents", "feeds", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
