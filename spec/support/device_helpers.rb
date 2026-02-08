# frozen_string_literal: true

# Helpers for creating and managing test devices in integration tests.
module DeviceHelpers
  def create_test_device(device_id: 'test-device-001', name: 'Test Phone', os: 'Android 13')
    payload = ApkPayload.find_or_create_by!(name: 'default') do |apk|
      apk.destination_ip = '127.0.0.1'
      apk.destination_port = '8080'
    end

    installation = ApkInstallation.find_or_create_by!(target_ip: device_id) do |inst|
      inst.apk_payload = payload
      inst.status = 'installed'
    end

    Smartphone.find_or_create_by!(device_id: device_id) do |phone|
      phone.apk_installation = installation
      phone.name = name
      phone.operating_system = os
      phone.is_rooted = 'false'
      phone.is_app_hidden = 'false'
    end
  end

  def create_online_device(device_id: 'online-device-001', **attrs)
    smartphone = create_test_device(device_id: device_id, **attrs)
    mark_device_online(smartphone)
    smartphone
  end

  def mark_device_online(smartphone)
    allow(DeviceConnectionChecker).to receive(:check_device_online)
      .with(smartphone)
      .and_return(true)
  end

  def mark_device_offline(smartphone)
    allow(DeviceConnectionChecker).to receive(:check_device_online)
      .with(smartphone)
      .and_return(false)
  end

  def stub_redis_device_tracking
    redis_double = double('redis')
    allow(redis_double).to receive(:sadd).and_return(true)
    allow(redis_double).to receive(:srem).and_return(true)
    allow(redis_double).to receive(:set).and_return('OK')
    allow(redis_double).to receive(:sismember).and_return(false)
    allow(redis_double).to receive(:smembers).and_return([])

    if defined?(RedisPool)
      allow(RedisPool).to receive(:with).and_yield(redis_double)
    end

    redis_double
  end
end

RSpec.configure do |config|
  config.include DeviceHelpers, type: :integration
end
