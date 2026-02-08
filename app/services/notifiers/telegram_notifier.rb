require 'net/http'
require 'uri'
require 'json'

class TelegramNotifier
  def initialize(config)
    @bot_token = config['bot_token']
    @chat_id = config['chat_id']
  end
  
  def send_alert(alert)
    unless @bot_token && @chat_id
      return { status: 'failed', error: 'Telegram bot token or chat ID not configured' }
    end
    
    message = build_telegram_message(alert)
    
    uri = URI.parse("https://api.telegram.org/bot#{@bot_token}/sendMessage")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      chat_id: @chat_id,
      text: message,
      parse_mode: 'Markdown'
    }.to_json
    
    response = http.request(request)
    parsed = JSON.parse(response.body)
    
    if parsed['ok']
      { status: 'sent', response: parsed }
    else
      { status: 'failed', error: parsed['description'], response: parsed }
    end
  rescue => e
    Rails.logger.error "TelegramNotifier error: #{e.message}"
    { status: 'failed', error: e.message }
  end
  
  private
  
  def build_telegram_message(alert)
    emoji = severity_emoji(alert.severity)
    
    message = "#{emoji} *#{escape_markdown(alert.title)}*\n\n"
    message += "*Severity:* #{alert.severity.upcase}\n"
    message += "*Device:* #{escape_markdown(alert.device.device_name || 'Unknown')} (#{alert.device.target_ip})\n"
    message += "*Event:* #{alert.alert_rule.event_type}\n"
    message += "*Time:* #{alert.triggered_at.strftime('%Y-%m-%d %H:%M:%S %Z')}\n\n"
    message += "*Message:*\n#{escape_markdown(alert.message)}"
    
    message
  end
  
  def severity_emoji(severity)
    {
      'low' => 'ℹ️',
      'medium' => '⚠️',
      'high' => '🔥',
      'critical' => '🚨'
    }[severity] || '📢'
  end
  
  def escape_markdown(text)
    text.to_s.gsub(/([_*\[\]()~`>#+\-=|{}.!])/, '\\\\\1')
  end
end
