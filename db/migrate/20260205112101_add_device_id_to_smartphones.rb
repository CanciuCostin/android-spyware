class AddDeviceIdToSmartphones < ActiveRecord::Migration[6.0]
  def change
    # Add device_id column (Android Settings.Secure.ANDROID_ID)
    add_column :smartphones, :device_id, :string unless column_exists?(:smartphones, :device_id)
    
    # Backfill existing records with target_ip as fallback
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE smartphones 
          SET device_id = COALESCE(
            (SELECT target_ip FROM apk_installations WHERE apk_installations.id = smartphones.apk_installation_id),
            'device_' || smartphones.id
          )
          WHERE device_id IS NULL OR device_id = '';
        SQL
      end
    end
    
    # Add index for fast lookups
    add_index :smartphones, :device_id, unique: true, if_not_exists: true
  end
end