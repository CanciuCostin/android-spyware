class AuditMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # Skip for WebSocket upgrade requests (ActionCable)
    return @app.call(env) if env['HTTP_UPGRADE']&.downcase == 'websocket'

    request = Rack::Request.new(env)
    
    # Store request context
    RequestStore.store[:current_ip_address] = extract_ip(request)
    RequestStore.store[:current_user_agent] = request.user_agent
    RequestStore.store[:request_params] = safe_params(request)
    RequestStore.store[:request_method] = request.request_method
    RequestStore.store[:request_path] = request.path
    RequestStore.store[:session_id] = extract_session_id(request)
    
    status, headers, response = @app.call(env)
    
    RequestStore.store[:response_status] = status
    
    [status, headers, response]
  ensure
    RequestStore.clear!
  end
  
  private
  
  def extract_ip(request)
    # Check for forwarded IP first (common in proxied environments)
    forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
    return forwarded_for.split(',').first.strip if forwarded_for.present?
    
    request.env['HTTP_X_REAL_IP'] || request.ip
  end
  
  def safe_params(request)
    request.params
  rescue => e
    Rails.logger.error "Error extracting params: #{e.message}"
    {}
  end
  
  def extract_session_id(request)
    request.session_options[:id] if request.respond_to?(:session_options)
  rescue => e
    Rails.logger.debug "Error extracting session ID: #{e.message}"
    nil
  end
end
