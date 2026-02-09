class AuditService
  def self.log(action:, auditable: nil, admin_user: nil, changes: {}, metadata: {})
    new(action, auditable, admin_user, changes, metadata).log
  end
  
  def initialize(action, auditable, admin_user, changes, metadata)
    @action = action
    @auditable = auditable
    @admin_user = admin_user || current_admin_user
    @changes = changes
    @metadata = metadata
  end
  
  def log
    AuditLog.create!(
      admin_user: @admin_user,
      action: @action,
      auditable: @auditable,
      changes: @changes,
      metadata: enriched_metadata,
      ip_address: current_ip_address,
      user_agent: current_user_agent,
      request_params: filtered_params,
      request_method: current_request_method,
      request_path: current_request_path,
      response_status: current_response_status
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Don't fail the main operation if audit fails
    nil
  end
  
  private
  
  def enriched_metadata
    @metadata.merge(
      timestamp: Time.current.iso8601,
      rails_env: Rails.env,
      session_id: current_session_id
    )
  end
  
  def current_admin_user
    RequestStore.store[:current_admin_user]
  end
  
  def current_ip_address
    RequestStore.store[:current_ip_address]
  end
  
  def current_user_agent
    RequestStore.store[:current_user_agent]
  end
  
  def filtered_params
    params = RequestStore.store[:request_params]
    return nil unless params
    
    params.except('password', 'password_confirmation', 'token', 'authenticity_token')&.to_json
  rescue => e
    Rails.logger.error "Error filtering params: #{e.message}"
    nil
  end
  
  def current_request_method
    RequestStore.store[:request_method]
  end
  
  def current_request_path
    RequestStore.store[:request_path]
  end
  
  def current_response_status
    RequestStore.store[:response_status]
  end
  
  def current_session_id
    RequestStore.store[:session_id]
  end
end
