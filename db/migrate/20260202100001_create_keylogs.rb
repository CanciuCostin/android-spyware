class CreateKeylogs < ActiveRecord::Migration[6.0]
  def change
    create_table :keylogs do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :device_id
      t.bigint :client_timestamp
      t.string :app_package
      t.string :app_name
      t.string :activity
      t.string :keystroke
      t.text :full_text
      t.string :input_type
      t.string :field_id
      t.string :event_type
      t.string :session_id

      t.timestamps
    end

    add_index :keylogs, :device_id
    add_index :keylogs, :client_timestamp
    add_index :keylogs, :app_package
    add_index :keylogs, :event_type
  end
end
