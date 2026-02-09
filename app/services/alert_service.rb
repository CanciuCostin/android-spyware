class AlertService
  def self.trigger(event_type, device, event_data = {})
    new(event_type, device, event_data).trigger
  end
  
  def initialize(event_type, device, event_data = {})
    @event_type = event_type
    @device = device
    @event_data = event_data
  end
  
  def trigger
    matching_rules = AlertRule.enabled.for_event(@event_type)
    alerts_created = []
    
    matching_rules.each do |rule|
      next unless rule.evaluate(@device, @event_data)
      
      alert = create_alert(rule)
      if alert
        alerts_created << alert
        broadcast_alert(alert)
      end
    end

    Rails.logger.info "AlertService: Created #{alerts_created.count} alert(s) for event #{@event_type}"
    alerts_created
  end

  private

  def broadcast_alert(alert)
    ActionCable.server.broadcast(
      "alerts_channel",
      {
        id: alert.id,
        severity: alert.severity,
        title: alert.title,
        message: alert.message,
        device_id: @device&.id,
        triggered_at: alert.triggered_at
      }
    )
  end
  
  def create_alert(rule)
    Alert.create!(
      alert_rule: rule,
      device: @device,
      severity: determine_severity(rule),
      title: build_title(rule),
      message: build_message(rule),
      metadata: @event_data.deep_stringify_keys,
      triggered_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to create alert for rule #{rule.name}: #{e.message}"
    nil
  end
  
  def determine_severity(rule)
    # Priority: event_data > rule metadata > default
    @event_data[:severity]&.to_s ||
      @event_data['severity']&.to_s ||
      rule.metadata&.dig('default_severity') ||
      'medium'
  end
  
  def build_title(rule)
    "#{rule.name}: #{@device.device_name || @device.target_ip}"
  end
  
  def build_message(rule)
    device_info = "Device: #{@device.device_name || 'Unknown'} (#{@device.target_ip})"
    event_info = "Event: #{@event_type}"
    time_info = "Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    
    message = [device_info, event_info, time_info].join("\n")
    
    if @event_data.present?
      message += "\n\nEvent Data:\n"
      message += format_event_data(@event_data)
    end
    
    message
  end
  
  def format_event_data(data)
    data.map do |key, value|
      "  #{key}: #{format_value(value)}"
    end.join("\n")
  end
  
  def format_value(value)
    case value
    when Hash, Array
      JSON.pretty_generate(value).gsub(/\n/, "\n    ")
    else
      value.to_s
    end
  rescue
    value.to_s
  end
end
