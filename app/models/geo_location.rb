class GeoLocation < ApplicationRecord
  belongs_to :smartphone
  
  validates :smartphone_id, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # Alias for backward compatibility with old column names
  alias_attribute :lat, :latitude
  alias_attribute :lng, :longitude
end
