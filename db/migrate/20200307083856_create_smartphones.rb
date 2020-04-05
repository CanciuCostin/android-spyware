class CreateSmartphones < ActiveRecord::Migration[6.0]
  def change
    create_table :smartphones do |t|
      t.string :operating_system
      t.string :name
      t.string :pictures
      t.string :screenshots
      t.string :videos
      t.string :recordings
      t.string :is_rooted
      t.string :call_logs
      t.string :contacts
      t.string :sms_messages
      t.string :geo_locations
      t.string :is_app_hidden

      t.timestamps
    end
  end
end
