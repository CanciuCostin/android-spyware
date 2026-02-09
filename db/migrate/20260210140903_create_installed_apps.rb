class CreateInstalledApps < ActiveRecord::Migration[6.0]
  def change
    create_table :installed_apps do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.string :package_name, null: false
      t.string :app_name
      t.string :version_name
      t.bigint :version_code
      t.boolean :is_system_app, default: false
      t.datetime :install_time
      t.datetime :last_update_time
      t.json :permissions, default: []
      t.json :metadata, default: {}
      t.timestamps
      
      t.index [:device_id, :package_name], unique: true
    end
  end
end
