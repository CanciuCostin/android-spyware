class DeviceTag < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation', foreign_key: :device_id
  
  validates :key, presence: true, uniqueness: { scope: :device_id }
  
  # Find devices by tag
  scope :with_tag, ->(key, value = nil) {
    where(key: key).then { |scope| value ? scope.where(value: value) : scope }
  }
end
