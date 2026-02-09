class NotificationChannelsController < ApplicationController
  before_action :set_notification_channel, only: [:show, :update, :destroy, :test]
  
  def index
    @channels = NotificationChannel.all.order(created_at: :desc)
    render json: @channels
  end
  
  def show
    render json: @channel
  end
  
  def create
    @channel = NotificationChannel.new(notification_channel_params)
    
    if @channel.save
      render json: @channel, status: :created
    else
      render json: { errors: @channel.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @channel.update(notification_channel_params)
      render json: @channel
    else
      render json: { errors: @channel.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @channel.destroy
    head :no_content
  end
  
  def test
    # Create a test alert to verify the channel
    device = ApkInstallation.first
    unless device
      render json: { error: 'No devices available for testing' }, status: :unprocessable_entity
      return
    end
    
    # Create a temporary test alert rule if none exists
    test_rule = AlertRule.find_or_create_by!(name: 'Test Alert Rule', event_type: 'device_online') do |rule|
      rule.notification_channels = [@channel.name]
      rule.enabled = false # Don't trigger automatically
    end
    
    alert = Alert.create!(
      alert_rule: test_rule,
      device: device,
      severity: 'low',
      title: 'Test Alert - Channel Verification',
      message: "This is a test alert to verify the #{@channel.name} notification channel.",
      triggered_at: Time.current
    )
    
    # Send test notification
    allowed_notifiers = {
      'email' => 'EmailNotifier',
      'slack' => 'SlackNotifier',
      'telegram' => 'TelegramNotifier',
      'webhook' => 'WebhookNotifier'
    }

    unless allowed_notifiers.key?(@channel.channel_type)
      render json: { error: "Unsupported channel type: #{@channel.channel_type}" }, status: :unprocessable_entity
      return
    end

    notifier_class = allowed_notifiers[@channel.channel_type].safe_constantize
    unless notifier_class
      render json: { error: "Could not find notifier for type: #{@channel.channel_type}" }, status: :internal_server_error
      return
    end

    notifier = notifier_class.new(@channel.config)
    result = notifier.send_alert(alert)
    
    # Log the result
    NotificationLog.create!(
      alert: alert,
      notification_channel: @channel,
      status: result[:status],
      error_message: result[:error],
      response_data: result[:response] || {}
    )
    
    render json: {
      success: result[:status] == 'sent',
      message: result[:status] == 'sent' ? 'Test alert sent successfully' : 'Test alert failed',
      details: result
    }
  rescue => e
    render json: { error: "Test failed: #{e.message}" }, status: :unprocessable_entity
  end
  
  private
  
  def set_notification_channel
    @channel = NotificationChannel.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Notification channel not found' }, status: :not_found
  end
  
  def notification_channel_params
    params.require(:notification_channel).permit(
      :channel_type,
      :name,
      :enabled,
      config: {}
    )
  end
end
