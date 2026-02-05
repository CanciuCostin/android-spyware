class RemoveDuplicateDeviceIdIndex < ActiveRecord::Migration[6.0]
  def change
    # Remove the duplicate index from 20260205111119_add_database_indexes.rb
    # since device_id column and its index are now properly created in 
    # 20260205112101_add_device_id_to_smartphones.rb
    
    # The index was already added in add_device_id_to_smartphones migration
    # This migration just ensures no conflicts exist
    
    # No-op: Index is already correctly created in the device_id migration
  end
end