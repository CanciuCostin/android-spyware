class CreateGeofencing < ActiveRecord::Migration[6.0]
  def change
    create_table :geofences do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :name, null: false
      t.float :lat
      t.float :lng
      t.float :radius_meters
      t.json :polygon_points
      t.boolean :active, default: true, null: false
      t.boolean :alert_on_entry, default: true, null: false
      t.boolean :alert_on_exit, default: false, null: false

      t.timestamps
    end

    add_index :geofences, :active
    add_index :geofences, [:smartphone_id, :active]

    create_table :geofence_events do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.references :geofence, null: false, foreign_key: true
      t.string :event_type, null: false
      t.float :lat, null: false
      t.float :lng, null: false
      t.datetime :triggered_at, null: false

      t.timestamps
    end

    add_index :geofence_events, :event_type
    add_index :geofence_events, :triggered_at
    add_index :geofence_events, [:smartphone_id, :triggered_at]
  end
end
