class FixGeoLocationColumns < ActiveRecord::Migration[6.0]
  def change
    # Rename lat/long to latitude/longitude for consistency
    rename_column :geo_locations, :lat, :latitude
    rename_column :geo_locations, :long, :longitude
    
    # Add missing columns used by CommandChannel
    add_column :geo_locations, :accuracy, :float unless column_exists?(:geo_locations, :accuracy)
    add_column :geo_locations, :altitude, :float unless column_exists?(:geo_locations, :altitude)
    add_column :geo_locations, :speed, :float unless column_exists?(:geo_locations, :speed)
    add_column :geo_locations, :captured_at, :datetime unless column_exists?(:geo_locations, :captured_at)
  end
end
