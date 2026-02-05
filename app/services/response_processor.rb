# frozen_string_literal: true

# Processes responses from Android devices via ResponseChannel
class ResponseProcessor
  def self.process(data)
    return unless data.is_a?(Hash)
    
    device_id = data['device_id']
    response_type = data['type'] || data['response_type']
    payload = data['payload'] || data['data']
    
    Rails.logger.info \"[ResponseProcessor] Processing '#{response_type}' from device #{device_id}\"
    
    case response_type
    when 'device_info'
      process_device_info(device_id, payload)
    when 'command_result'
      process_command_result(device_id, payload)
    when 'error'
      process_error(device_id, payload)
    else
      Rails.logger.warn \"[ResponseProcessor] Unknown response type: #{response_type}\"
    end
  rescue StandardError => e
    Rails.logger.error \"[ResponseProcessor] Error: #{e.message}\"
    Rails.logger.error e.backtrace.join(\"\\n\")
  end
  
  private
  
  def self.process_device_info(device_id, payload)
    return unless payload.is_a?(Hash)
    
    smartphone = Smartphone.find_by(device_id: device_id)
    return unless smartphone
    
    smartphone.update(
      name: payload['model'] || smartphone.name,
      operating_system: \"Android #{payload['android_version']}\" || smartphone.operating_system,
      is_rooted: payload['is_rooted'] || smartphone.is_rooted
    )
    
    Rails.logger.info \"[ResponseProcessor] Updated device info for #{device_id}\"
  end
  
  def self.process_command_result(device_id, payload)
    return unless payload.is_a?(Hash)
    
    command_id = payload['command_id']
    success = payload['success']
    result = payload['result']
    
    # Store in cache or database as needed
    Rails.cache.write(\"command_result:#{device_id}:#{command_id}\", {
      success: success,
      result: result,
      timestamp: Time.current.to_i
    }, expires_in: 1.hour)
    
    Rails.logger.info \"[ResponseProcessor] Command #{command_id} result: #{success}\"
  end
  
  def self.process_error(device_id, payload)
    return unless payload.is_a?(Hash)
    
    error_message = payload['error'] || payload['message']
    Rails.logger.error \"[ResponseProcessor] Device #{device_id} error: #{error_message}\"
    
    # Could send alert, notification, etc.
  end
end