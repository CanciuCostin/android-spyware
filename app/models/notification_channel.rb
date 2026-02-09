class NotificationChannel < ApplicationRecord
  include Auditable
  
  has_many :notification_logs, dependent: :destroy
  
  SUPPORTED_TYPES = %w[email webhook slack telegram sms].freeze
  
  validates :channel_type, inclusion: { in: SUPPORTED_TYPES }
  validates :name, presence: true, uniqueness: true
  
  scope :enabled, -> { where(enabled: true) }
  scope :of_type, ->(type) { where(channel_type: type) }
  
  def self.default_email_channel
    find_or_create_by!(name: 'default_email', channel_type: 'email') do |channel|
      channel.config = {
        'to' => ENV['ADMIN_EMAIL'] || 'admin@eaglespy.local',
        'from' => ENV['ALERT_FROM_EMAIL'] || 'alerts@eaglespy.local'
      }
    end
  end
end
