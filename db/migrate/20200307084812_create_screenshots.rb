class CreateScreenshots < ActiveRecord::Migration[6.0]
  def change
    create_table :screenshots do |t|
      t.date :date
      t.string :duration
      t.string :filename
      t.references :smartphone, null: false, foreign_key: true

      t.timestamps
    end
  end
end
