class AddDatabaseIndexes < ActiveRecord::Migration[6.0]
  def change
    # Note: device_id index is created in add_device_id_to_smartphones migration
    
    # Add index on apk_installations.target_ip for faster device queries
    add_index :apk_installations, :target_ip, if_not_exists: true
    
    # Add indexes on foreign keys (Rails doesn't auto-create them)
    add_index :smartphones, :apk_installation_id, if_not_exists: true
    add_index :call_logs, :smartphone_id, if_not_exists: true
    add_index :contacts, :smartphone_id, if_not_exists: true
    add_index :geo_locations, :smartphone_id, if_not_exists: true
    add_index :messaging_apps_dumps, :smartphone_id, if_not_exists: true
    add_index :pictures, :smartphone_id, if_not_exists: true
    add_index :recordings, :smartphone_id, if_not_exists: true
    add_index :screenshots, :smartphone_id, if_not_exists: true
    add_index :sms_messages, :smartphone_id, if_not_exists: true
  end
end