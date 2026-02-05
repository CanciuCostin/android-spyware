class FixGeoLocationColumnTypes < ActiveRecord::Migration[6.0]
  def up
    # Change lat and long from string to decimal with proper precision
    change_column :geo_locations, :lat, :decimal, precision: 10, scale: 6
    change_column :geo_locations, :long, :decimal, precision: 10, scale: 6
    
    # Rename columns to match model expectations
    rename_column :geo_locations, :lat, :latitude
    rename_column :geo_locations, :long, :longitude
  end

  def down
    # Rollback: rename back and convert to string
    rename_column :geo_locations, :latitude, :lat
    rename_column :geo_locations, :longitude, :long
    change_column :geo_locations, :lat, :string
    change_column :geo_locations, :long, :string
  end
end
