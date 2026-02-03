# app/services/device_connection_checker.rb
class DeviceConnectionChecker
  def self.check_device_online(smartphone)
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
    redis.sismember('online_devices', smartphone.device_id)
  rescue => e
    Rails.logger.error("Error checking device connection: #{e.message}")
    false
  end
  
  def self.get_online_devices
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
    redis.smembers('online_devices')
  rescue => e
    Rails.logger.error("Error getting online devices: #{e.message}")
    []
  end
  
  def self.get_device_info(device_id)
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
    info_json = redis.get("device_info:#{device_id}")
    info_json ? JSON.parse(info_json) : nil
  rescue => e
    Rails.logger.error("Error getting device info: #{e.message}")
    nil
  end
end
