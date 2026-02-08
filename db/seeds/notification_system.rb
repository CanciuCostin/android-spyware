# Notification System Seeds

puts "Setting up Notification System..."

# Create default email channel
email_channel = NotificationChannel.find_or_create_by!(name: 'default_email') do |channel|
  channel.channel_type = 'email'
  channel.config = {
    'to' => ENV['ADMIN_EMAIL'] || 'admin@eaglespy.local',
    'from' => ENV['ALERT_FROM_EMAIL'] || 'alerts@eaglespy.local'
  }
  channel.enabled = true
end
puts "✓ Created email notification channel: #{email_channel.name}"

# Create sample alert rules
rules = [
  {
    name: 'Critical Device Offline',
    event_type: 'device_offline',
    notification_channels: ['default_email'],
    metadata: { default_severity: 'high' },
    cooldown_minutes: 60
  },
  {
    name: 'Device Back Online',
    event_type: 'device_online',
    notification_channels: ['default_email'],
    metadata: { default_severity: 'low' },
    cooldown_minutes: 30
  },
  {
    name: 'Low Battery Alert',
    event_type: 'battery_low',
    notification_channels: ['default_email'],
    conditions: {
      'battery_level' => { 'operator' => '<', 'value' => 20 }
    },
    metadata: { default_severity: 'medium' },
    cooldown_minutes: 120
  },
  {
    name: 'Critical Battery Alert',
    event_type: 'battery_low',
    notification_channels: ['default_email'],
    conditions: {
      'battery_level' => { 'operator' => '<', 'value' => 10 }
    },
    metadata: { default_severity: 'critical' },
    cooldown_minutes: 120
  }
]

rules.each do |rule_data|
  rule = AlertRule.find_or_create_by!(name: rule_data[:name]) do |r|
    r.event_type = rule_data[:event_type]
    r.notification_channels = rule_data[:notification_channels]
    r.conditions = rule_data[:conditions] || {}
    r.metadata = rule_data[:metadata] || {}
    r.cooldown_minutes = rule_data[:cooldown_minutes]
    r.enabled = true
  end
  puts "✓ Created alert rule: #{rule.name}"
end

puts "\n✅ Notification System setup complete!"
puts "\nNext steps:"
puts "1. Configure additional notification channels (Slack, Webhook, etc.)"
puts "2. Customize alert rules for your needs"
puts "3. Test notification channels with POST /notification_channels/:id/test"
puts "\nSee NOTIFICATION_SYSTEM_DOCUMENTATION.md for detailed usage."
