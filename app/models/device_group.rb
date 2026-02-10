class DeviceGroup < ApplicationRecord
  include Auditable
  
  has_many :device_group_memberships, dependent: :destroy
  has_many :devices, through: :device_group_memberships, source: :device
  
  validates :name, presence: true, uniqueness: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }
  
  # Aggregated stats
  def online_count
    devices.where(status: 'online').count
  end
  
  def total_count
    devices.count
  end
  
  def battery_average
    devices.average(:battery_level)&.round(1) || 0
  end
  
  def last_activity
    devices.maximum(:last_seen_at)
  end
  
  # Bulk operations
  def send_command_to_all(command_type, params = {})
    devices.where(status: 'online').includes(:pending_commands).find_each do |device|
      # Use existing CommandSender concern
      # This would be called from controller context
    end
  end
end
