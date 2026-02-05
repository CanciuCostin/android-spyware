class AddUniqueIndexToSmartphonesDeviceId < ActiveRecord::Migration[6.0]
  def change
    add_index :smartphones, :device_id, unique: true
  end
end
