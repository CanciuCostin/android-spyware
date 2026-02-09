class AlertRule < ApplicationRecord
  include Auditable
  
  has_many :alerts, dependent: :destroy
  
  validates :name, presence: true
  validates :event_type, presence: true
  validates :notification_channels, presence: true
  
  SUPPORTED_EVENTS = [
    'device_offline',
    'device_online',
    'battery_low',
    'geofence_breach',
    'keyword_detected',
    'app_installed',
    'new_photo',
    'new_screenshot',
    'new_recording',
    'suspicious_activity',
    'high_data_usage',
    'location_changed'
  ].freeze
  
  validates :event_type, inclusion: { in: SUPPORTED_EVENTS }
  
  scope :enabled, -> { where(enabled: true) }
  scope :for_event, ->(event) { where(event_type: event) }
  
  def evaluate(device, event_data = {})
    return false unless enabled?
    
    # Check if in cooldown period
    return false if in_cooldown?(device)
    
    # Evaluate conditions
    evaluate_conditions(device, event_data)
  end
  
  private
  
  def in_cooldown?(device)
    return false if cooldown_minutes.zero?
    
    last_alert = alerts.where(device: device)
                       .where('triggered_at > ?', cooldown_minutes.minutes.ago)
                       .exists?
    last_alert
  end
  
  def evaluate_conditions(device, event_data)
    return true if conditions.blank?
    
    conditions.all? do |field, rule|
      value = extract_value(device, event_data, field)
      evaluate_operator(value, rule['operator'], rule['value'])
    end
  end
  
  def extract_value(device, event_data, field)
    # Try device attribute first
    return device.send(field) if device.respond_to?(field)
    
    # Try event data
    event_data[field] || event_data[field.to_sym]
  end
  
  def evaluate_operator(value, operator, target)
    return false if value.nil?
    
    case operator
    when '==' then value.to_s == target.to_s
    when '!=' then value.to_s != target.to_s
    when '>' then value.to_f > target.to_f
    when '<' then value.to_f < target.to_f
    when '>=' then value.to_f >= target.to_f
    when '<=' then value.to_f <= target.to_f
    when 'contains' then value.to_s.include?(target.to_s)
    when 'matches' then value.to_s =~ /#{target}/
    when 'in' then Array(target).include?(value)
    when 'not_in' then !Array(target).include?(value)
    else false
    end
  rescue => e
    Rails.logger.error "Error evaluating condition: #{e.message}"
    false
  end
end
