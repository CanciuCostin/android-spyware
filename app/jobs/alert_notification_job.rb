class AlertNotificationJob < ApplicationJob
  queue_as :notifications
  
  def perform(alert_id)
    alert = Alert.find_by(id: alert_id)
    unless alert
      Rails.logger.warn "AlertNotificationJob: Alert #{alert_id} not found"
      return
    end
    
    channels = alert.alert_rule.notification_channels
    Rails.logger.info "AlertNotificationJob: Processing alert #{alert_id} for #{channels.count} channel(s)"
    
    channels.each do |channel_name|
      send_to_channel(alert, channel_name)
    end
  rescue => e
    Rails.logger.error "AlertNotificationJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
  
  private
  
  def send_to_channel(alert, channel_name)
    channel = NotificationChannel.enabled.find_by(name: channel_name)
    unless channel
      Rails.logger.warn "Notification channel '#{channel_name}' not found or disabled"
      log_notification(alert, nil, { status: 'failed', error: 'Channel not found' })
      return
    end
    
    notifier = notifier_for_channel(channel)
    result = notifier.send_alert(alert)
    
    log_notification(alert, channel, result)
  rescue => e
    Rails.logger.error "Failed to send to channel #{channel_name}: #{e.message}"
    log_notification(alert, channel, { status: 'failed', error: e.message })
  end
  
  def notifier_for_channel(channel)
    case channel.channel_type
    when 'email' then EmailNotifier.new(channel.config)
    when 'webhook' then WebhookNotifier.new(channel.config)
    when 'slack' then SlackNotifier.new(channel.config)
    when 'telegram' then TelegramNotifier.new(channel.config)
    else raise "Unsupported channel type: #{channel.channel_type}"
    end
  end
  
  def log_notification(alert, channel, result)
    NotificationLog.create!(
      alert: alert,
      notification_channel: channel,
      status: result[:status] || 'failed',
      error_message: result[:error],
      response_data: result[:response] || {}
    )
  end
end
