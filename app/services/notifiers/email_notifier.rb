class EmailNotifier
  def initialize(config)
    @to = config['to'] || ENV['ADMIN_EMAIL'] || 'admin@eaglespy.local'
    @from = config['from'] || ENV['ALERT_FROM_EMAIL'] || 'alerts@eaglespy.local'
  end
  
  def send_alert(alert)
    AlertMailer.alert_notification(alert, @to, @from).deliver_later
    { status: 'sent' }
  rescue => e
    Rails.logger.error "EmailNotifier error: #{e.message}"
    { status: 'failed', error: e.message }
  end
end
