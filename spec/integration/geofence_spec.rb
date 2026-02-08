# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geofence Integration', type: :integration do
  let(:device_id) { 'test-device-geo-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }

  describe 'location updates and geofence alerting' do
    it 'saves location update from device via CommandChannel' do
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      channel.receive({
        'type' => 'location_update',
        'data' => {
          'latitude' => 40.7128,
          'longitude' => -74.0060,
          'timestamp' => (Time.utc(2025, 1, 15, 12, 0, 0).to_i * 1000).to_s
        }
      })

      location = GeoLocation.last
      expect(location).to be_present
      expect(location.smartphone).to eq(smartphone)
      expect(location.lat.to_f).to be_within(0.001).of(40.7128)
      expect(location.long.to_f).to be_within(0.001).of(-74.0060)
    end

    it 'broadcasts location to admin channel for live map' do
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      channel.receive({
        'type' => 'location_update',
        'data' => {
          'latitude' => 40.7128,
          'longitude' => -74.0060
        }
      })

      admin_msgs = broadcasted_messages_for("location_#{device_id}_admin")
      expect(admin_msgs.size).to eq(1)
      expect(admin_msgs.first[:type]).to eq('location_update')
      expect(admin_msgs.first[:device_id]).to eq(device_id)
    end

    it 'rejects invalid coordinates' do
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      initial_count = GeoLocation.count

      channel.receive({
        'type' => 'location_update',
        'data' => {
          'latitude' => 999.0,
          'longitude' => -999.0
        }
      })

      expect(GeoLocation.count).to eq(initial_count)
    end

    it 'handles missing latitude gracefully' do
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      initial_count = GeoLocation.count

      channel.receive({
        'type' => 'location_update',
        'data' => {
          'longitude' => -74.0060
        }
      })

      expect(GeoLocation.count).to eq(initial_count)
    end
  end

  describe 'geofence breach alerts' do
    let!(:geofence_rule) do
      AlertRule.create!(
        name: 'Office Geofence',
        event_type: 'geofence_breach',
        conditions: {},
        notification_channels: ['email'],
        enabled: true,
        cooldown_minutes: 0,
        metadata: { 'default_severity' => 'high' }
      )
    end

    it 'triggers geofence alert when AlertService is called' do
      allow(AlertService).to receive(:trigger).and_call_original
      allow(AlertNotificationJob).to receive_message_chain(:perform_later)

      alerts = AlertService.trigger(
        'geofence_breach',
        smartphone.apk_installation,
        {
          latitude: 40.7128,
          longitude: -74.0060,
          geofence_name: 'Office'
        }
      )

      expect(alerts.size).to eq(1)
      expect(alerts.first.severity).to eq('high')
      expect(alerts.first.alert_rule).to eq(geofence_rule)
    end

    it 'respects cooldown period for repeated alerts' do
      allow(AlertService).to receive(:trigger).and_call_original
      allow(AlertNotificationJob).to receive_message_chain(:perform_later)

      geofence_rule.update!(cooldown_minutes: 60)

      # First trigger
      alerts1 = AlertService.trigger('geofence_breach', smartphone.apk_installation, {})
      expect(alerts1.size).to eq(1)

      # Second trigger within cooldown — should be suppressed
      alerts2 = AlertService.trigger('geofence_breach', smartphone.apk_installation, {})
      expect(alerts2.size).to eq(0)
    end
  end

  describe 'multiple location updates from same device' do
    it 'stores sequential location history' do
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      locations = [
        { 'latitude' => 40.7128, 'longitude' => -74.0060 },
        { 'latitude' => 40.7138, 'longitude' => -74.0050 },
        { 'latitude' => 40.7148, 'longitude' => -74.0040 }
      ]

      locations.each do |loc|
        channel.receive({
          'type' => 'location_update',
          'data' => loc
        })
      end

      expect(smartphone.geo_locations.count).to eq(3)
    end
  end

  describe 'alert rule conditions' do
    it 'evaluates conditions on device attributes' do
      rule = AlertRule.create!(
        name: 'Rooted Device Alert',
        event_type: 'device_online',
        conditions: { 'is_rooted' => { 'operator' => '==', 'value' => 'true' } },
        notification_channels: ['email'],
        enabled: true,
        cooldown_minutes: 0
      )

      # Device is not rooted — rule should not match
      expect(rule.evaluate(smartphone.apk_installation)).to be false
    end

    it 'matches when conditions are empty (catch-all rule)' do
      rule = AlertRule.create!(
        name: 'All Events',
        event_type: 'location_changed',
        conditions: {},
        notification_channels: ['email'],
        enabled: true,
        cooldown_minutes: 0
      )

      expect(rule.evaluate(smartphone.apk_installation)).to be true
    end

    it 'does not evaluate disabled rules' do
      rule = AlertRule.create!(
        name: 'Disabled Rule',
        event_type: 'geofence_breach',
        conditions: {},
        notification_channels: ['email'],
        enabled: false,
        cooldown_minutes: 0
      )

      expect(rule.evaluate(smartphone.apk_installation)).to be false
    end
  end

  describe 'coordinate validation' do
    it 'accepts valid coordinate ranges' do
      channel = CommandChannel.allocate

      expect(channel.send(:valid_coordinates?, 0, 0)).to be true
      expect(channel.send(:valid_coordinates?, -90, -180)).to be true
      expect(channel.send(:valid_coordinates?, 90, 180)).to be true
      expect(channel.send(:valid_coordinates?, 51.5074, -0.1278)).to be true
    end

    it 'rejects out-of-range coordinates' do
      channel = CommandChannel.allocate

      expect(channel.send(:valid_coordinates?, 91, 0)).to be false
      expect(channel.send(:valid_coordinates?, -91, 0)).to be false
      expect(channel.send(:valid_coordinates?, 0, 181)).to be false
      expect(channel.send(:valid_coordinates?, 0, -181)).to be false
    end

    it 'rejects nil coordinates' do
      channel = CommandChannel.allocate

      expect(channel.send(:valid_coordinates?, nil, -74.0)).to be false
      expect(channel.send(:valid_coordinates?, 40.7, nil)).to be false
    end
  end
end
