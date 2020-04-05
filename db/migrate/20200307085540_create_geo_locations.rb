class CreateGeoLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :geo_locations do |t|
      t.date :date
      t.string :lat
      t.string :long
      t.references :smartphone, null: false, foreign_key: true

      t.timestamps
    end
  end
end
