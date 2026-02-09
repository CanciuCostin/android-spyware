class AddMissingForeignKeys < ActiveRecord::Migration[6.0]
  def change
    # Add foreign keys to tables that reference smartphones
    # Using on_delete: :cascade to clean up orphaned records
    
    add_foreign_key :call_logs, :smartphones, on_delete: :cascade unless foreign_key_exists?(:call_logs, :smartphones)
    add_foreign_key :contacts, :smartphones, on_delete: :cascade unless foreign_key_exists?(:contacts, :smartphones)
    add_foreign_key :geo_locations, :smartphones, on_delete: :cascade unless foreign_key_exists?(:geo_locations, :smartphones)
    add_foreign_key :messaging_apps_dumps, :smartphones, on_delete: :cascade unless foreign_key_exists?(:messaging_apps_dumps, :smartphones)
    add_foreign_key :pictures, :smartphones, on_delete: :cascade unless foreign_key_exists?(:pictures, :smartphones)
    add_foreign_key :recordings, :smartphones, on_delete: :cascade unless foreign_key_exists?(:recordings, :smartphones)
    add_foreign_key :screenshots, :smartphones, on_delete: :cascade unless foreign_key_exists?(:screenshots, :smartphones)
    add_foreign_key :sms_messages, :smartphones, on_delete: :cascade unless foreign_key_exists?(:sms_messages, :smartphones)
    
    # Add composite index for pending_commands (smartphone_id + status)
    unless index_exists?(:pending_commands, [:smartphone_id, :status])
      add_index :pending_commands, [:smartphone_id, :status], name: 'index_pending_commands_on_smartphone_and_status'
    end
    
    # Add timestamps to apk_installations if missing
    unless column_exists?(:apk_installations, :created_at)
      add_timestamps :apk_installations, null: true
    end
  end
end