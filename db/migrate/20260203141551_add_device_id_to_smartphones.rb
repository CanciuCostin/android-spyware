class AddDeviceIdToSmartphones < ActiveRecord::Migration[6.0]
  def change
    add_column :smartphones, :device_id, :string
    add_index :smartphones, :device_id, unique: true
  end
end
