class GeofenceEvent < ApplicationRecord
  belongs_to :smartphone
  belongs_to :geofence

  validates :event_type, presence: true, inclusion: { in: %w[entry exit] }
  validates :lat, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :lng, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :triggered_at, presence: true

  scope :entry_events, -> { where(event_type: 'entry') }
  scope :exit_events, -> { where(event_type: 'exit') }
  scope :recent, -> { order(triggered_at: :desc) }
  scope :for_device, ->(smartphone_id) { where(smartphone_id: smartphone_id) }
end
