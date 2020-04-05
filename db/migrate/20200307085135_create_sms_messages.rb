class CreateSmsMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :sms_messages do |t|
      t.date :date
      t.string :source
      t.string :destination
      t.text :content
      t.references :smartphone, null: false, foreign_key: true

      t.timestamps
    end
  end
end
