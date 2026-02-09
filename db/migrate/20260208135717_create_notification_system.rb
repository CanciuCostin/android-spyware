class CreateNotificationSystem < ActiveRecord::Migration[6.0]
  def change
    # Alert Rules
    create_table :alert_rules do |t|
      t.string :name, null: false
      t.string :event_type, null: false # 'device_offline', 'geofence_breach', 'keyword_detected', etc.
      t.json :conditions, default: {} # {"battery_level": {"operator": "<", "value": 20}}
      t.json :notification_channels, default: [] # ['email', 'webhook', 'sms']
      t.boolean :enabled, default: true
      t.integer :cooldown_minutes, default: 60 # Prevent spam
      t.json :metadata, default: {}
      t.timestamps
    end
    
    # Alert History
    create_table :alerts do |t|
      t.references :alert_rule, foreign_key: true
      t.references :device, foreign_key: { to_table: :apk_installations }
      t.string :severity # 'low', 'medium', 'high', 'critical'
      t.string :title, null: false
      t.text :message
      t.json :metadata, default: {}
      t.datetime :triggered_at
      t.datetime :acknowledged_at
      t.references :acknowledged_by, foreign_key: { to_table: :admin_users }
      t.timestamps
    end
    
    # Notification Channels Config
    create_table :notification_channels do |t|
      t.string :channel_type, null: false # 'email', 'webhook', 'slack', 'telegram'
      t.string :name, null: false
      t.json :config, default: {} # Channel-specific config
      t.boolean :enabled, default: true
      t.timestamps
    end
    
    # Notification Logs
    create_table :notification_logs do |t|
      t.references :alert, foreign_key: true
      t.references :notification_channel, foreign_key: true
      t.string :status # 'sent', 'failed', 'pending'
      t.text :error_message
      t.json :response_data, default: {}
      t.timestamps
    end
    
    add_index :alert_rules, :event_type
    add_index :alert_rules, :enabled
    add_index :alerts, [:device_id, :triggered_at]
    add_index :alerts, :severity
    add_index :notification_logs, [:alert_id, :status]
  end
end
