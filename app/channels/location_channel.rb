# Live Location Updates Channel
class LocationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "location_#{params[:device_id]}"
    Rails.logger.info "[LocationChannel] Subscribed to device #{params[:device_id]}"
  end

  def unsubscribed
    Rails.logger.info "[LocationChannel] Unsubscribed from device #{params[:device_id]}"
  end

  # Receive location update from Android device
  def update_location(data)
    device_id = params[:device_id]
    
    # Save to database
    smartphone = Smartphone.find_by(id: device_id)
    if smartphone
      GeoLocation.create!(
        lat: data['lat'],
        long: data['lng'],
        date: Time.current.strftime("%Y-%m-%d %H:%M:%S"),
        smartphone_id: smartphone.id
      )
    end

    # Broadcast to admin viewers
    ActionCable.server.broadcast(
      "location_#{device_id}_admin",
      {
        type: 'location_update',
        device_id: device_id,
        lat: data['lat'],
        lng: data['lng'],
        accuracy: data['accuracy'],
        speed: data['speed'],
        bearing: data['bearing'],
        timestamp: Time.current.to_i
      }
    )
  end

  # Admin subscribes to watch a device's location
  def watch_device(data)
    stream_from "location_#{data['device_id']}_admin"
    
    # Request device to start sending location
    ActionCable.server.broadcast(
      "location_#{data['device_id']}",
      { type: 'start_location', interval: data['interval'] || 5000 }
    )
  end

  # Stop watching device location
  def stop_watching(data)
    ActionCable.server.broadcast(
      "location_#{data['device_id']}",
      { type: 'stop_location' }
    )
  end
end
