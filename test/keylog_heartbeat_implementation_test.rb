# frozen_string_literal: true

# Quick validation test for Keylog and Heartbeat features
require 'test_helper'

class KeylogHeartbeatImplementationTest < ActiveSupport::TestCase
  # Test that KeylogResponseProcessor is defined and can be instantiated
  def test_keylog_response_processor_exists
    assert defined?(KeylogResponseProcessor), "KeylogResponseProcessor class should be defined"
    assert KeylogResponseProcessor.instance_methods.include?(:initialize), "KeylogResponseProcessor should have initialize method"
    assert KeylogResponseProcessor.instance_methods.include?(:process), "KeylogResponseProcessor should have process method"
  end

  # Test that HeartbeatMonitor is defined with necessary methods
  def test_heartbeat_monitor_exists
    assert defined?(HeartbeatMonitor), "HeartbeatMonitor class should be defined"
    assert HeartbeatMonitor.respond_to?(:process_heartbeat), "HeartbeatMonitor should have process_heartbeat class method"
    assert HeartbeatMonitor.respond_to?(:get_last_seen), "HeartbeatMonitor should have get_last_seen class method"
    assert HeartbeatMonitor.respond_to?(:is_online?), "HeartbeatMonitor should have is_online? class method"
    assert HeartbeatMonitor.respond_to?(:get_all_online_devices), "HeartbeatMonitor should have get_all_online_devices class method"
    assert HeartbeatMonitor.respond_to?(:mark_offline), "HeartbeatMonitor should have mark_offline class method"
  end

  # Test that DeviceStatusHelper is defined
  def test_device_status_helper_exists
    assert defined?(DeviceStatusHelper), "DeviceStatusHelper module should be defined"
    assert DeviceStatusHelper.instance_methods.include?(:device_online?), "Helper should have device_online? method"
    assert DeviceStatusHelper.instance_methods.include?(:smartphone_online?), "Helper should have smartphone_online? method"
    assert DeviceStatusHelper.instance_methods.include?(:device_last_seen), "Helper should have device_last_seen method"
  end

  # Test that ResponseProcessor includes keylog in processors
  def test_response_processor_has_keylog_mapping
    assert defined?(ResponseProcessor), "ResponseProcessor class should be defined"
    assert ResponseProcessor::COMMAND_PROCESSORS.key?('keylog'), "ResponseProcessor should have 'keylog' command mapping"
    assert ResponseProcessor::COMMAND_PROCESSORS['keylog'] == KeylogResponseProcessor, "Keylog should map to KeylogResponseProcessor"
  end

  # Test that Keylog model exists with necessary fields
  def test_keylog_model_exists
    assert defined?(Keylog), "Keylog model should be defined"
    keylog = Keylog.new
    assert keylog.respond_to?(:smartphone), "Keylog should have smartphone association"
    assert keylog.respond_to?(:keystroke), "Keylog should have keystroke field"
    assert keylog.respond_to?(:app_name), "Keylog should have app_name field"
    assert keylog.respond_to?(:app_package), "Keylog should have app_package field"
  end
end
