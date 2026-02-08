class CreateSecurityAnalysis < ActiveRecord::Migration[6.0]
  def change
    create_table :security_events do |t|
      t.string :device_id, null: false
      t.string :event_type, null: false
      t.string :severity, null: false, default: 'info'
      t.text :details
      t.datetime :detected_at, null: false

      t.timestamps

      t.index :device_id
      t.index :event_type
      t.index :severity
      t.index :detected_at
      t.index [:device_id, :event_type], name: 'index_security_events_on_device_and_type'
      t.index [:severity, :detected_at], name: 'index_security_events_on_severity_and_time'
    end
  end
end
