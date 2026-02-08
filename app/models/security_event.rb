# frozen_string_literal: true

class SecurityEvent < ApplicationRecord
  validates :device_id, presence: true
  validates :event_type, presence: true
  validates :severity, presence: true, inclusion: { in: %w[info low medium high critical] }
  validates :detected_at, presence: true

  scope :critical, -> { where(severity: 'critical') }
  scope :high_and_above, -> { where(severity: %w[critical high]) }
  scope :for_device, ->(device_id) { where(device_id: device_id) }
  scope :recent, ->(hours = 24) { where('detected_at > ?', hours.hours.ago) }
end
