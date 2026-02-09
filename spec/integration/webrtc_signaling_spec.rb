# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WebRTC Signaling Flow', type: :integration do
  let(:device_id) { 'test-device-webrtc-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }

  let(:sample_sdp_offer) do
    {
      'type' => 'offer',
      'sdp' => 'v=0\r\no=- 1234567890 1 IN IP4 127.0.0.1\r\ns=-\r\n'
    }
  end

  let(:sample_sdp_answer) do
    {
      'type' => 'answer',
      'sdp' => 'v=0\r\no=- 9876543210 1 IN IP4 127.0.0.1\r\ns=-\r\n'
    }
  end

  let(:sample_ice_candidate) do
    {
      'candidate' => 'candidate:1 1 UDP 2130706431 192.168.1.1 12345 typ host',
      'sdpMid' => '0',
      'sdpMLineIndex' => 0
    }
  end

  describe 'WebRTC offer/answer exchange via SignalingChannel' do
    it 'forwards offer from device to admin stream' do
      device_channel = simulate_signaling_subscription(device_id, is_admin: false)
      device_channel.subscribed

      device_channel.offer({ 'sdp' => sample_sdp_offer['sdp'], 'device_id' => device_id })

      admin_messages = broadcasted_messages_for("signaling_admin_#{device_id}")
      expect(admin_messages.size).to eq(1)
      expect(admin_messages.first[:type]).to eq('offer')
      expect(admin_messages.first[:sdp]).to eq(sample_sdp_offer['sdp'])
      expect(admin_messages.first[:device_id]).to eq(device_id)
    end

    it 'forwards answer from admin to device stream' do
      admin_channel = simulate_signaling_subscription(device_id, is_admin: true)
      admin_channel.subscribed

      admin_channel.answer({ 'sdp' => sample_sdp_answer['sdp'], 'device_id' => device_id })

      device_messages = broadcasted_messages_for("signaling_device_#{device_id}")
      expect(device_messages.size).to eq(1)
      expect(device_messages.first[:type]).to eq('answer')
      expect(device_messages.first[:sdp]).to eq(sample_sdp_answer['sdp'])
    end
  end

  describe 'ICE candidate forwarding' do
    it 'forwards ICE candidate from device to admin' do
      device_channel = simulate_signaling_subscription(device_id, is_admin: false)
      device_channel.subscribed

      device_channel.ice_candidate({
        'candidate' => sample_ice_candidate['candidate'],
        'device_id' => device_id,
        'target' => 'admin'
      })

      admin_messages = broadcasted_messages_for("signaling_admin_#{device_id}")
      expect(admin_messages.size).to eq(1)
      expect(admin_messages.first[:type]).to eq('ice_candidate')
      expect(admin_messages.first[:candidate]).to eq(sample_ice_candidate['candidate'])
    end

    it 'forwards ICE candidate from admin to device' do
      admin_channel = simulate_signaling_subscription(device_id, is_admin: true)
      admin_channel.subscribed

      admin_channel.ice_candidate({
        'candidate' => sample_ice_candidate['candidate'],
        'device_id' => device_id,
        'target' => 'device'
      })

      device_messages = broadcasted_messages_for("signaling_device_#{device_id}")
      expect(device_messages.size).to eq(1)
      expect(device_messages.first[:type]).to eq('ice_candidate')
    end
  end

  describe 'session lifecycle (create → active → close)' do
    it 'completes full signaling handshake: start_stream → offer → answer → ICE' do
      admin_channel = simulate_signaling_subscription(device_id, is_admin: true)
      admin_channel.subscribed
      device_channel = simulate_signaling_subscription(device_id, is_admin: false)
      device_channel.subscribed

      # Step 1: Admin requests stream
      admin_channel.start_stream({ 'device_id' => device_id, 'stream_type' => 'camera' })

      device_start_msgs = broadcasted_messages_for("signaling_device_#{device_id}")
      expect(device_start_msgs.last[:type]).to eq('start_stream_request')
      expect(device_start_msgs.last[:stream_type]).to eq('camera')

      # Step 2: Device sends offer
      device_channel.offer({ 'sdp' => sample_sdp_offer['sdp'], 'device_id' => device_id })

      admin_msgs = broadcasted_messages_for("signaling_admin_#{device_id}")
      expect(admin_msgs.last[:type]).to eq('offer')

      # Step 3: Admin sends answer
      admin_channel.answer({ 'sdp' => sample_sdp_answer['sdp'], 'device_id' => device_id })

      device_msgs = broadcasted_messages_for("signaling_device_#{device_id}")
      answer_msg = device_msgs.find { |m| m[:type] == 'answer' }
      expect(answer_msg).to be_present

      # Step 4: ICE candidates exchanged
      device_channel.ice_candidate({
        'candidate' => 'candidate:1 1 UDP 2130706431 10.0.0.1 1234 typ host',
        'target' => 'admin'
      })
      admin_channel.ice_candidate({
        'candidate' => 'candidate:2 1 UDP 2130706431 10.0.0.2 5678 typ host',
        'target' => 'device'
      })

      final_admin_msgs = broadcasted_messages_for("signaling_admin_#{device_id}")
      final_device_msgs = broadcasted_messages_for("signaling_device_#{device_id}")

      ice_to_admin = final_admin_msgs.select { |m| m[:type] == 'ice_candidate' }
      ice_to_device = final_device_msgs.select { |m| m[:type] == 'ice_candidate' }

      expect(ice_to_admin.size).to eq(1)
      expect(ice_to_device.size).to eq(1)
    end

    it 'sends stop_stream request to device' do
      admin_channel = simulate_signaling_subscription(device_id, is_admin: true)
      admin_channel.subscribed

      admin_channel.stop_stream({ 'device_id' => device_id })

      device_msgs = broadcasted_messages_for("signaling_device_#{device_id}")
      expect(device_msgs.last[:type]).to eq('stop_stream_request')
    end
  end

  describe 'multiple concurrent sessions' do
    let(:device_id_2) { 'test-device-webrtc-002' }
    let!(:smartphone_2) { create_test_device(device_id: device_id_2) }

    it 'isolates signaling streams between different devices' do
      ch1 = simulate_signaling_subscription(device_id, is_admin: false)
      ch1.subscribed
      ch2 = simulate_signaling_subscription(device_id_2, is_admin: false)
      ch2.subscribed

      ch1.offer({ 'sdp' => 'offer-for-device-1', 'device_id' => device_id })
      ch2.offer({ 'sdp' => 'offer-for-device-2', 'device_id' => device_id_2 })

      msgs_dev1 = broadcasted_messages_for("signaling_admin_#{device_id}")
      msgs_dev2 = broadcasted_messages_for("signaling_admin_#{device_id_2}")

      expect(msgs_dev1.size).to eq(1)
      expect(msgs_dev1.first[:sdp]).to eq('offer-for-device-1')
      expect(msgs_dev2.size).to eq(1)
      expect(msgs_dev2.first[:sdp]).to eq('offer-for-device-2')
    end
  end

  describe 'error handling' do
    it 'sanitizes device_id in signaling channel' do
      channel = SignalingChannel.allocate
      sanitized = channel.send(:sanitize_device_id, 'dev<script>alert</script>')

      expect(sanitized).to eq('devalert')
      expect(sanitized).not_to include('<')
      expect(sanitized).not_to include('>')
    end

    it 'uses default device_id when not provided in offer data' do
      channel = simulate_signaling_subscription(device_id, is_admin: false)
      channel.subscribed

      # Offer without explicit device_id — should default to @device_id
      channel.offer({ 'sdp' => 'test-sdp' })

      msgs = broadcasted_messages_for("signaling_admin_#{device_id}")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:device_id]).to eq(device_id)
    end
  end

  describe 'REST-based signaling via WebrtcController' do
    it 'broadcasts offer via REST endpoint' do
      post '/webrtc/signal', params: {
        device_id: device_id,
        signal_type: 'offer',
        payload: sample_sdp_offer['sdp']
      }

      expect(response).to have_http_status(:ok)

      msgs = broadcasted_messages_for("streaming_#{device_id}_admin")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:type]).to eq('offer')
    end

    it 'broadcasts answer via REST endpoint' do
      post '/webrtc/signal', params: {
        device_id: device_id,
        signal_type: 'answer',
        payload: sample_sdp_answer['sdp']
      }

      expect(response).to have_http_status(:ok)

      msgs = broadcasted_messages_for("streaming_#{device_id}")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:type]).to eq('answer')
    end

    it 'routes ICE candidate to correct target via REST' do
      post '/webrtc/signal', params: {
        device_id: device_id,
        signal_type: 'ice_candidate',
        payload: sample_ice_candidate['candidate'],
        target: 'device'
      }

      expect(response).to have_http_status(:ok)

      msgs = broadcasted_messages_for("streaming_#{device_id}")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:type]).to eq('ice_candidate')
    end
  end
end
