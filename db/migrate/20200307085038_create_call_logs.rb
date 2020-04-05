class CreateCallLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :call_logs do |t|
      t.date :date
      t.string :source
      t.string :destination
      t.string :duration
      t.string :filename
      t.references :smartphone, null: false, foreign_key: true

      t.timestamps
    end
  end
end
