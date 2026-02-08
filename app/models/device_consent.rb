class DeviceConsent < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation'
  
  CONSENT_TYPES = %w[
    device_monitoring
    location_tracking
    data_collection
    microphone_access
    camera_access
    sms_monitoring
    call_logging
  ].freeze
  
  validates :consent_type, presence: true, inclusion: { in: CONSENT_TYPES }
  validates :consent_type, uniqueness: { scope: :device_id }
  
  scope :granted, -> { where(granted: true, revoked_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :by_type, ->(type) { where(consent_type: type) }
  
  def grant!(granted_by:, ip_address:, consent_text:, version:)
    update!(
      granted: true,
      granted_at: Time.current,
      granted_by: granted_by,
      ip_address: ip_address,
      consent_text: consent_text,
      consent_version: version,
      revoked_at: nil
    )
    
    log_consent_change('granted')
  end
  
  def revoke!
    update!(
      granted: false,
      revoked_at: Time.current
    )
    
    log_consent_change('revoked')
    notify_admins_of_revocation
  end
  
  def active?
    granted? && revoked_at.nil?
  end
  
  private
  
  def log_consent_change(action)
    AuditService.log(
      action: action,
      auditable: self,
      metadata: {
        consent_type: consent_type,
        device_id: device_id,
        granted_by: granted_by
      }
    )
  rescue => e
    Rails.logger.error "Failed to log consent change: #{e.message}"
  end
  
  def notify_admins_of_revocation
    AdminMailer.consent_revoked(self).deliver_later if defined?(AdminMailer)
  rescue => e
    Rails.logger.error "Failed to notify admins: #{e.message}"
  end
end
