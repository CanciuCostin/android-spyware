# app/services/device_connection_checker.rb
class DeviceConnectionChecker
  def self.check_device_online(smartphone)
    RedisPool.with do |redis|
      redis.sismember('online_devices', smartphone.device_id)
    end
  rescue => e
    Rails.logger.error("Error checking device connection: #{e.message}")
    false
  end
  
  def self.get_online_devices
    RedisPool.with do |redis|
      redis.smembers('online_devices')
    end
  rescue => e
    Rails.logger.error("Error getting online devices: #{e.message}")
    []
  end
  
  def self.get_device_info(device_id)
    RedisPool.with do |redis|
      info_json = redis.get("device_info:#{device_id}")
      info_json ? JSON.parse(info_json) : nil
    end
  rescue => e
    Rails.logger.error("Error getting device info: #{e.message}")
    nil
  end
end
