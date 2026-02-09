class ConsentsController < ApplicationController
  include ErrorHandler
  include ResponseFormatter
  
  before_action :set_device
  skip_before_action :authenticate_admin_user!, raise: false
  
  def index
    service = ConsentService.new(@device)
    render_success(service.consent_status)
  end
  
  def grant
    service = ConsentService.new(@device)
    result = service.grant_consent(
      params[:consent_type],
      granted_by: current_admin_user&.email || 'system',
      ip_address: request.remote_ip
    )
    
    if result.success?
      render_created(result.value, message: 'Consent granted')
    else
      render_error(result.error)
    end
  end
  
  def revoke
    service = ConsentService.new(@device)
    result = service.revoke_consent(params[:consent_type])
    
    if result.success?
      render_success(result.value, message: 'Consent revoked')
    else
      render_error(result.error)
    end
  end
  
  def export
    service = ConsentService.new(@device)
    send_data service.export_consent_history.to_json,
              filename: "consent_history_#{@device.id}_#{Date.today}.json",
              type: 'application/json'
  end
  
  private
  
  def set_device
    @device = ApkInstallation.find(params[:device_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Device not found', status: :not_found)
  end
end
