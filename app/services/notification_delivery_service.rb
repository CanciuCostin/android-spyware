# frozen_string_literal: true

# Delivers notifications through multiple channels using the strategy pattern.
# Supports email, webhook, Slack, Telegram, and in-app channels with
# per-channel retry logic and delivery confirmation tracking.
class NotificationDeliveryService
  include ServiceInterface
  include DependencyInjectable

  dependency :logger,  default: -> { StructuredLogger }
  dependency :metrics, default: -> { MetricsService }

  MAX_RETRIES = 3
  RETRY_DELAYS = [1, 5, 15].freeze # seconds

  # Channel registry — maps channel name to notifier class
  CHANNELS = {
    'email'    => 'EmailNotifier',
    'webhook'  => 'WebhookNotifier',
    'slack'    => 'SlackNotifier',
    'telegram' => 'TelegramNotifier'
  }.freeze

  def initialize(alert:, channels: nil, **deps)
    @alert = alert
    @requested_channels = channels
    inject_dependencies(deps)
  end

  def call
    return failure("Alert is required") if @alert.nil?

    channels_to_use = resolve_channels
    return failure("No delivery channels configured") if channels_to_use.empty?

    results = channels_to_use.map { |channel, config| deliver(channel, config) }

    any_success = results.any? { |r| r[:status] == 'sent' }
    track_delivery(results)

    log_summary(results)

    if any_success
      success(results)
    else
      failure("All delivery channels failed: #{results.map { |r| r[:error] }.compact.join('; ')}")
    end
  end

  private

  def resolve_channels
    configured = notification_config
    return {} if configured.blank?

    if @requested_channels.present?
      configured.slice(*Array(@requested_channels))
    else
      configured.select { |_, cfg| cfg['enabled'] != false }
    end
  end

  def notification_config
    @notification_config ||= begin
      if defined?(Rails.application.credentials) && Rails.application.credentials.dig(:notifications)
        Rails.application.credentials.notifications.deep_stringify_keys
      else
        YAML.safe_load(
          ERB.new(File.read(Rails.root.join('config', 'notifications.yml'))).result,
          permitted_classes: [Symbol]
        ).fetch(Rails.env, {})
      end
    rescue StandardError => e
      logger.warn("Failed to load notification config", error: e)
      {}
    end
  end

  def deliver(channel_name, config)
    notifier_class = CHANNELS[channel_name]
    unless notifier_class
      return { channel: channel_name, status: 'skipped', error: "Unknown channel: #{channel_name}" }
    end

    notifier = notifier_class.constantize.new(config)
    result = deliver_with_retry(notifier, channel_name)

    record_delivery(channel_name, result)
    result.merge(channel: channel_name)
  rescue NameError => e
    { channel: channel_name, status: 'failed', error: "Notifier not found: #{e.message}" }
  rescue StandardError => e
    { channel: channel_name, status: 'failed', error: e.message }
  end

  def deliver_with_retry(notifier, channel_name)
    attempts = 0

    loop do
      result = notifier.send_alert(@alert)
      return result if result[:status] == 'sent'

      attempts += 1
      break result if attempts >= MAX_RETRIES

      delay = RETRY_DELAYS[attempts - 1] || RETRY_DELAYS.last
      logger.warn("Retry #{attempts}/#{MAX_RETRIES} for #{channel_name} in #{delay}s",
        error_msg: result[:error])
      sleep(delay)
    end
  end

  def record_delivery(channel_name, result)
    return unless @alert.respond_to?(:notification_deliveries)

    @alert.notification_deliveries.create(
      channel: channel_name,
      status: result[:status],
      error_message: result[:error],
      delivered_at: result[:status] == 'sent' ? Time.current : nil
    )
  rescue StandardError => e
    logger.warn("Failed to record delivery", error: e, channel: channel_name)
  end

  def track_delivery(results)
    results.each do |result|
      metrics.increment("notification_deliveries_total",
        labels: { channel: result[:channel], status: result[:status] })
    end
  rescue StandardError
    # Metrics failures must not break the flow
  end

  def log_summary(results)
    sent = results.count { |r| r[:status] == 'sent' }
    failed = results.count { |r| r[:status] == 'failed' }

    logger.info("Notification delivery complete",
      alert_id: @alert.respond_to?(:id) ? @alert.id : nil,
      sent: sent,
      failed: failed,
      channels: results.map { |r| "#{r[:channel]}:#{r[:status]}" }.join(', '))
  end
end
