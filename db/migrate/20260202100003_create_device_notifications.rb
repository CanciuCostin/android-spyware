class CreateDeviceNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :device_notifications do |t|
      t.string :device_id, null: false
      t.string :package_name, null: false
      t.string :app_name
      t.string :title
      t.text :content
      t.string :sub_text
      t.string :category
      t.integer :notification_id
      t.string :group_key
      t.boolean :is_ongoing, default: false
      t.boolean :is_clearable, default: true
      t.bigint :post_time
      t.datetime :received_at

      t.timestamps
    end

    add_index :device_notifications, :device_id
    add_index :device_notifications, :package_name
    add_index :device_notifications, :post_time
    add_index :device_notifications, [:device_id, :post_time]
  end
end
