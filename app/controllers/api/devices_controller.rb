# API Controller for device status queries
class Api::DevicesController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/devices/online
  # Returns list of currently connected devices
  def online
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
    device_ids = redis.smembers('online_devices')
    
    devices = device_ids.map do |device_id|
      last_seen = redis.get("device:#{device_id}:last_seen")
      {
        device_id: device_id,
        last_seen: last_seen ? Time.at(last_seen.to_i) : nil,
        online: true
      }
    end
    
    redis.close
    
    render json: { devices: devices, count: devices.size }
  rescue => e
    Rails.logger.warn "[API::DevicesController] Redis error: #{e.message}"
    render json: { devices: [], count: 0 }
  end
end
