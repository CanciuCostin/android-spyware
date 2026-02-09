class GeoLocation < ApplicationRecord
  include Paginatable

  belongs_to :smartphone
  
  validates :smartphone_id, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  
  # Backward compatibility aliases (deprecated, use latitude/longitude)
  alias_attribute :lat, :latitude
  alias_attribute :long, :longitude
  alias_attribute :lng, :longitude
end
