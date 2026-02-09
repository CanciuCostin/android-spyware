class GeoLocation < ApplicationRecord
  include Paginatable

  belongs_to :smartphone
  
  validates :smartphone_id, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  
  def latitude
    self[:lat]&.to_f
  end

  def latitude=(value)
    self[:lat] = value
  end

  def longitude
    self[:long]&.to_f
  end

  def longitude=(value)
    self[:long] = value
  end

  alias_method :lng, :longitude
  alias_method :lng=, :longitude=
end
