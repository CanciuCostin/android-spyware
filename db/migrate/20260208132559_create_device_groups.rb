class CreateDeviceGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :device_groups do |t|
      t.string :name, null: false
      t.string :description
      t.string :color # For UI visualization
      t.json :metadata, default: {}
      t.timestamps
    end
    
    create_table :device_group_memberships do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.references :device_group, null: false, foreign_key: true
      t.timestamps
      
      t.index [:device_id, :device_group_id], unique: true, name: 'idx_device_group_unique'
    end
    
    create_table :device_tags do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.string :key, null: false
      t.string :value
      t.timestamps
      
      t.index [:device_id, :key], unique: true
    end
    
    add_index :device_groups, :name, unique: true
  end
end
