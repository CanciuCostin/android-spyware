class DeviceGroupMembership < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation', foreign_key: :device_id
  belongs_to :device_group
  
  validates :device_id, uniqueness: { scope: :device_group_id }
end
