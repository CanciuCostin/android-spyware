class ConsentEnforcement
  PROTECTED_ENDPOINTS = {
    'location' => 'location_tracking',
    'microphone' => 'microphone_access',
    'camera' => 'camera_access',
    'sms' => 'sms_monitoring'
  }.freeze
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # Skip for WebSocket upgrade requests (ActionCable)
    return @app.call(env) if env['HTTP_UPGRADE']&.downcase == 'websocket'

    request = Rack::Request.new(env)
    
    if requires_consent_check?(request)
      device_id = extract_device_id(request)
      consent_type = required_consent_type(request)
      
      unless consent_granted?(device_id, consent_type)
        return consent_denied_response(consent_type)
      end
    end
    
    @app.call(env)
  end
  
  private
  
  def requires_consent_check?(request)
    PROTECTED_ENDPOINTS.keys.any? { |path| request.path.include?(path) }
  end
  
  def extract_device_id(request)
    request.params['device_id'] || 
      request.env['HTTP_X_DEVICE_ID'] || 
      request.path.match(/devices\/([^\/]+)/)&.then { |m| m[1] }
  rescue
    nil
  end
  
  def required_consent_type(request)
    PROTECTED_ENDPOINTS.find { |k, v| request.path.include?(k) }&.last
  end
  
  def consent_granted?(device_id, consent_type)
    return false unless device_id && consent_type
    
    device = Smartphone.find_by(device_id: device_id) || Smartphone.find_by(id: device_id)
    return false unless device
    
    ConsentService.new(device).check_consent(consent_type)
  rescue => e
    Rails.logger.error "Consent check failed: #{e.message}"
    false
  end
  
  def consent_denied_response(consent_type)
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{ error: "Consent required: #{consent_type}", code: 'CONSENT_REQUIRED' }.to_json]
    ]
  end
end
