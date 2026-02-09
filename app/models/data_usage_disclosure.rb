class DataUsageDisclosure < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation'
  
  DISCLOSURE_TYPES = %w[initial update annual].freeze
  
  validates :disclosure_type, presence: true, inclusion: { in: DISCLOSURE_TYPES }
  
  scope :acknowledged, -> { where(acknowledged: true) }
  scope :pending, -> { where(acknowledged: false) }
  
  def acknowledge!
    update!(
      acknowledged: true,
      acknowledged_at: Time.current
    )
  end
end
