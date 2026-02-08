class CreateDeviceSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :device_settings do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :key, null: false
      t.string :value, null: false
      t.timestamps
    end

    add_index :device_settings, [:smartphone_id, :key], unique: true
  end
end
