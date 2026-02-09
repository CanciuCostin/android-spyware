class CreateSocialMediaMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :social_media_messages do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :app_name
      t.string :sender
      t.text :body
      t.datetime :sent_at

      t.timestamps
    end
  end
end
