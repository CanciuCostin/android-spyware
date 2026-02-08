class Geofence < ApplicationRecord
  belongs_to :smartphone
  has_many :geofence_events, dependent: :destroy

  validates :name, presence: true
  validates :smartphone_id, presence: true
  validates :radius_meters, numericality: { greater_than: 0 }, allow_nil: true
  validates :lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :lng, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validate :must_have_circle_or_polygon

  scope :active, -> { where(active: true) }
  scope :for_device, ->(smartphone_id) { where(smartphone_id: smartphone_id) }
  scope :alerting_entry, -> { where(alert_on_entry: true) }
  scope :alerting_exit, -> { where(alert_on_exit: true) }

  def circle?
    lat.present? && lng.present? && radius_meters.present? && polygon_points.blank?
  end

  def polygon?
    polygon_points.present? && polygon_points.is_a?(Array) && polygon_points.length >= 3
  end

  private

  def must_have_circle_or_polygon
    return if circle? || polygon?

    errors.add(:base, 'Must define either a circle (lat, lng, radius_meters) or polygon (polygon_points)')
  end
end
