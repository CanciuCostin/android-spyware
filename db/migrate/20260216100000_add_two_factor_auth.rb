# frozen_string_literal: true

class AddTwoFactorAuth < ActiveRecord::Migration[6.0]
  def change
    create_table :admin_two_factors do |t|
      t.references :admin_user, null: false, foreign_key: true, index: { unique: true }
      t.string :otp_secret, null: false
      t.boolean :enabled, default: false, null: false
      t.json :backup_codes, default: []
      t.datetime :last_used_at
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :locked_until

      t.timestamps
    end

    create_table :admin_sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :session_token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_activity_at, null: false
      t.datetime :expires_at, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :admin_sessions, :session_token, unique: true
    add_index :admin_sessions, [:admin_user_id, :active]
    add_index :admin_sessions, :expires_at

    create_table :remembered_devices do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :device_fingerprint, null: false
      t.string :user_agent
      t.string :ip_address
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :remembered_devices, [:admin_user_id, :device_fingerprint], name: 'idx_remembered_devices_lookup'
    add_index :remembered_devices, :expires_at

    create_table :api_keys do |t|
      t.references :admin_user, foreign_key: true
      t.string :device_id
      t.string :key_digest, null: false
      t.string :key_prefix, null: false
      t.string :name, null: false
      t.string :scope, default: 'read_only', null: false
      t.integer :usage_count, default: 0, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.boolean :revoked, default: false, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_keys, :key_digest, unique: true
    add_index :api_keys, :key_prefix
    add_index :api_keys, [:device_id, :revoked]
    add_index :api_keys, :revoked
  end
end
