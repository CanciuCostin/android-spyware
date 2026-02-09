# frozen_string_literal: true

class DeviceSetting < ApplicationRecord
  belongs_to :smartphone

  validates :key, presence: true, uniqueness: { scope: :smartphone_id }
  validates :value, presence: true

  scope :for_device, ->(device) { where(smartphone: device) }
  scope :by_key, ->(key) { where(key: key) }
end
