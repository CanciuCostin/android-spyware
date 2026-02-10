class ApkInstallation < ApplicationRecord
  include Auditable
  
  belongs_to :apk_payload
  has_many :device_group_memberships, foreign_key: :device_id, dependent: :destroy
  has_many :device_groups, through: :device_group_memberships
  has_many :device_tags, foreign_key: :device_id, dependent: :destroy
  has_many :installed_apps, foreign_key: :device_id, dependent: :destroy
  has_many :pending_commands, foreign_key: :device_id, dependent: :destroy
  has_many :device_consents, foreign_key: :device_id, dependent: :destroy
  has_many :terms_acceptances, foreign_key: :device_id, dependent: :destroy
  has_many :data_usage_disclosures, foreign_key: :device_id, dependent: :destroy
  
  # Validations
  validates :target_ip, presence: true, format: {
    with: /\A[a-zA-Z0-9_.:-]+\z/,
    message: "must contain only letters, numbers, dots, colons, underscores, or hyphens"
  }
  validates :status, inclusion: { in: %w[pending installed failed], allow_blank: true }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  after_commit :check_alert_triggers, on: :update
  
  # Tag helper methods
  def add_tag(key, value = nil)
    device_tags.create_or_find_by!(key: key).update(value: value)
  end
  
  def remove_tag(key)
    device_tags.where(key: key).destroy_all
  end
  
  def tag(key)
    device_tags.find_by(key: key)&.value
  end
  
  def tags_hash
    device_tags.pluck(:key, :value).to_h
  end
  
  private
  
  def set_default_status
    self.status ||= 'pending'
  end
  
  def check_alert_triggers
    # Trigger offline alert
    if saved_change_to_status? && status == 'offline'
      AlertService.trigger('device_offline', self)
    end

    # Trigger online alert
    if saved_change_to_status? && status == 'installed'
      AlertService.trigger('device_online', self)
    end

    # Trigger battery low alert
    if saved_change_to_battery_level? && battery_level && battery_level < 20
      AlertService.trigger('battery_low', self, { battery_level: battery_level })
    end
  rescue StandardError => e
    Rails.logger.error("AlertService trigger failed for device #{id}: #{e.message}")
  end
end
