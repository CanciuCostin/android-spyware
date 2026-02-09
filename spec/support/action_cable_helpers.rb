# frozen_string_literal: true

# Helpers for testing ActionCable channels in integration tests.
# Provides mock broadcasting and subscription tracking.
module ActionCableHelpers
  extend ActiveSupport::Concern

  included do
    before do
      @broadcasted_messages = Hash.new { |h, k| h[k] = [] }
      @rejected_subscriptions = []

      allow(ActionCable.server).to receive(:broadcast) do |stream, message|
        @broadcasted_messages[stream] << message
      end
    end
  end

  def broadcasted_messages_for(stream)
    @broadcasted_messages[stream]
  end

  def last_broadcast_for(stream)
    @broadcasted_messages[stream].last
  end

  def broadcast_count_for(stream)
    @broadcasted_messages[stream].size
  end

  def clear_broadcasts!
    @broadcasted_messages.clear
  end

  # Simulate a device connecting via ActionCable and subscribing to CommandChannel
  def simulate_device_subscription(device_id, token: 'test-device-token')
    channel = CommandChannel.new(
      mock_connection_for_helpers(device_id: device_id, token: token),
      { device_id: device_id }
    )
    allow(channel).to receive(:stream_from)
    allow(channel).to receive(:transmit)
    channel
  end

  # Simulate a signaling channel subscription
  def simulate_signaling_subscription(device_id, is_admin: false)
    channel = SignalingChannel.new(
      mock_connection_for_helpers(device_id: device_id),
      { device_id: device_id, is_admin: is_admin.to_s }
    )
    allow(channel).to receive(:stream_from)
    allow(channel).to receive(:transmit)
    channel
  end

  # Simulate a file browser channel subscription
  def simulate_file_browser_subscription(device_id)
    channel = FileBrowserChannel.new(
      mock_connection_for_helpers(device_id: device_id),
      { device_id: device_id }
    )
    allow(channel).to receive(:stream_from)
    allow(channel).to receive(:transmit)
    channel
  end

  private

  def mock_connection_for_helpers(device_id: nil, token: nil)
    conn = double('connection')
    allow(conn).to receive(:logger).and_return(Rails.logger)
    allow(conn).to receive(:identifiers).and_return([:current_identifier, :current_user_type])
    allow(conn).to receive(:current_identifier).and_return(device_id)
    allow(conn).to receive(:current_user_type).and_return(:device)
    allow(conn).to receive(:transmit)
    conn
  end
end

RSpec.configure do |config|
  config.include ActionCableHelpers, type: :integration
  config.include ActionCableHelpers, type: :channel
end
