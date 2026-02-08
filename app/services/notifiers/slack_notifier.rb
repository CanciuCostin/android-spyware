require 'net/http'
require 'uri'
require 'json'

class SlackNotifier
  def initialize(config)
    @webhook_url = config['webhook_url']
    @username = config['username'] || 'EagleSpy Alerts'
    @icon_emoji = config['icon_emoji'] || ':rotating_light:'
  end
  
  def send_alert(alert)
    unless @webhook_url
      return { status: 'failed', error: 'Slack webhook URL not configured' }
    end
    
    payload = build_slack_payload(alert)
    
    uri = URI.parse(@webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    
    if response.code.to_i == 200
      { status: 'sent', response: { body: response.body } }
    else
      { status: 'failed', error: "HTTP #{response.code}", response: { body: response.body } }
    end
  rescue => e
    Rails.logger.error "SlackNotifier error: #{e.message}"
    { status: 'failed', error: e.message }
  end
  
  private
  
  def build_slack_payload(alert)
    {
      username: @username,
      icon_emoji: @icon_emoji,
      text: "🚨 *#{alert.title}*",
      attachments: [{
        color: severity_color(alert.severity),
        fields: [
          {
            title: "Severity",
            value: alert.severity.upcase,
            short: true
          },
          {
            title: "Device",
            value: "#{alert.device.device_name || 'Unknown'} (#{alert.device.target_ip})",
            short: true
          },
          {
            title: "Event Type",
            value: alert.alert_rule.event_type,
            short: true
          },
          {
            title: "Time",
            value: alert.triggered_at.strftime('%Y-%m-%d %H:%M:%S %Z'),
            short: true
          },
          {
            title: "Message",
            value: alert.message,
            short: false
          }
        ],
        footer: "EagleSpy V5",
        ts: alert.triggered_at.to_i
      }]
    }
  end
  
  def severity_color(severity)
    {
      'low' => 'good',
      'medium' => 'warning',
      'high' => 'danger',
      'critical' => '#FF0000'
    }[severity] || '#808080'
  end
end
