class CreateNotificationMedia < ActiveRecord::Migration[6.0]
  def change
    create_table :notification_media do |t|
      t.references :device_notification, null: false, foreign_key: true
      t.string :media_type, null: false  # 'icon', 'large_icon', 'big_picture'
      t.binary :data
      t.string :mime_type

      t.timestamps
    end

    add_index :notification_media, :media_type
  end
end
