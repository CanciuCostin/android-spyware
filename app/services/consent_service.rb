class ConsentService < ApplicationService
  def initialize(device)
    @device = device
  end
  
  def grant_consent(consent_type, options = {})
    consent = @device.device_consents.find_or_initialize_by(consent_type: consent_type)
    
    consent.grant!(
      granted_by: options[:granted_by],
      ip_address: options[:ip_address],
      consent_text: generate_consent_text(consent_type),
      version: current_consent_version
    )
    
    Result.success(consent)
  rescue => e
    Result.failure(e.message)
  end
  
  def revoke_consent(consent_type)
    consent = @device.device_consents.find_by(consent_type: consent_type)
    return Result.failure("Consent not found") unless consent
    
    consent.revoke!
    stop_related_operations(consent_type)
    
    Result.success(consent)
  rescue => e
    Result.failure(e.message)
  end
  
  def check_consent(consent_type)
    consent = @device.device_consents.find_by(consent_type: consent_type)
    consent&.active? || false
  end
  
  def consent_status
    DeviceConsent::CONSENT_TYPES.map do |type|
      consent = @device.device_consents.find_by(consent_type: type)
      {
        type: type,
        granted: consent&.active? || false,
        granted_at: consent&.granted_at,
        revoked_at: consent&.revoked_at
      }
    end
  end
  
  def export_consent_history
    {
      device_id: @device.id,
      consents: @device.device_consents.map(&:attributes),
      terms: @device.terms_acceptances.map(&:attributes),
      disclosures: @device.data_usage_disclosures.map(&:attributes),
      exported_at: Time.current
    }
  end
  
  private
  
  def generate_consent_text(consent_type)
    I18n.t("consents.#{consent_type}.text", default: "Consent for #{consent_type.humanize}")
  end
  
  def current_consent_version
    ENV['CONSENT_VERSION'] || '1.0'
  end
  
  def stop_related_operations(consent_type)
    case consent_type
    when 'location_tracking'
      DeviceCommandService.call(@device, 'stop_location_tracking') if defined?(DeviceCommandService)
    when 'microphone_access'
      DeviceCommandService.call(@device, 'stop_microphone') if defined?(DeviceCommandService)
    when 'camera_access'
      DeviceCommandService.call(@device, 'stop_camera') if defined?(DeviceCommandService)
    end
  rescue => e
    Rails.logger.error "Failed to stop related operations: #{e.message}"
  end
end
