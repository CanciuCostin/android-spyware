require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class WebhookNotifier
  def initialize(config)
    @url = config['url']
    @secret = config['secret']
    @timeout = config['timeout'] || 10
  end
  
  def send_alert(alert)
    unless @url
      return { status: 'failed', error: 'Webhook URL not configured' }
    end
    
    payload = build_payload(alert)
    signature = generate_signature(payload) if @secret
    
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = @timeout
    http.open_timeout = @timeout
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['X-Webhook-Signature'] = signature if signature
    request.body = payload
    
    response = http.request(request)
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      { status: 'sent', response: { code: response.code, body: response.body } }
    else
      { status: 'failed', error: "HTTP #{response.code}", response: { body: response.body } }
    end
  rescue => e
    Rails.logger.error "WebhookNotifier error: #{e.message}"
    { status: 'failed', error: e.message }
  end
  
  private
  
  def build_payload(alert)
    {
      alert_id: alert.id,
      severity: alert.severity,
      title: alert.title,
      message: alert.message,
      device_id: alert.device_id,
      device_name: alert.device&.device_name,
      device_ip: alert.device&.target_ip,
      triggered_at: alert.triggered_at.iso8601,
      metadata: alert.metadata,
      alert_rule: {
        id: alert.alert_rule.id,
        name: alert.alert_rule.name,
        event_type: alert.alert_rule.event_type
      }
    }.to_json
  end
  
  def generate_signature(payload)
    OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)
  end
end
