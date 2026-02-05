# API Controller for device status queries
module Api
  class DevicesController < Api::BaseController

  # GET /api/devices/online
  # Returns list of currently connected devices
  def online
    devices = RedisPool.with do |redis|
      device_ids = redis.smembers('online_devices')
      
      device_ids.map do |device_id|
        last_seen = redis.get("device:#{device_id}:last_seen")
        {
          device_id: device_id,
          last_seen: last_seen ? Time.at(last_seen.to_i) : nil,
          online: true
        }
      end
    end
    
    render json: { devices: devices, count: devices.size }
  rescue => e
    Rails.logger.warn "[API::DevicesController] Redis error: #{e.message}"
    render json: { devices: [], count: 0 }
  end
end
