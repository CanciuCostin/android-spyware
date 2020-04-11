class RemoveCreatedAtUpdatedAtFromGeoLocations < ActiveRecord::Migration[6.0]
  def change

    remove_column :geo_locations, :created_at, :datetime

    remove_column :geo_locations, :updated_at, :datetime
  end
end
