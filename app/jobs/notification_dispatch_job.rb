# frozen_string_literal: true

# Dispatches notifications asynchronously to configured channels.
# Supports multiple channel types and batched delivery.
#
# Usage:
#   NotificationDispatchJob.perform_later(type: 'device_offline', payload: { device_id: 42 })
#   NotificationDispatchJob.perform_later(type: 'alert', payload: { ... }, channels: ['email'])
class NotificationDispatchJob < ApplicationJob
  queue_as :notifications

  VALID_TYPES = %w[device_offline device_online alert command_failed data_export_ready].freeze

  def perform(type:, payload: {}, channels: nil)
    unless VALID_TYPES.include?(type.to_s)
      Rails.logger.warn "[NotificationDispatchJob] Unknown type: #{type}"
      return
    end

    target_channels = resolve_channels(channels)
    if target_channels.empty?
      Rails.logger.info "[NotificationDispatchJob] No enabled channels for type=#{type}"
      return
    end

    delivered = 0
    target_channels.each do |channel|
      deliver_to_channel(channel, type, payload)
      delivered += 1
    rescue StandardError => e
      Rails.logger.error "[NotificationDispatchJob] Channel #{channel.name} failed: #{e.message}"
    end

    Rails.logger.info "[NotificationDispatchJob] type=#{type} delivered=#{delivered}/#{target_channels.size}"
    MetricsService.increment(:notifications_sent_total, labels: { type: type })
  end

  private

  def resolve_channels(channel_names)
    scope = NotificationChannel.enabled
    scope = scope.where(name: channel_names) if channel_names.present?
    scope.to_a
  rescue StandardError => e
    Rails.logger.error "[NotificationDispatchJob] Channel resolution failed: #{e.message}"
    []
  end

  def deliver_to_channel(channel, type, payload)
    notifier = build_notifier(channel)
    message = format_message(type, payload)
    notifier.deliver(message)
  end

  def build_notifier(channel)
    case channel.channel_type
    when 'email'    then EmailNotifier.new(channel.config)
    when 'webhook'  then WebhookNotifier.new(channel.config)
    when 'slack'    then SlackNotifier.new(channel.config)
    when 'telegram' then TelegramNotifier.new(channel.config)
    else raise "Unsupported channel type: #{channel.channel_type}"
    end
  end

  def format_message(type, payload)
    {
      title: type.to_s.titleize,
      body: payload[:message] || "#{type.titleize} event",
      timestamp: Time.current.iso8601,
      data: payload
    }
  end
end
