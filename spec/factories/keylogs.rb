# frozen_string_literal: true

FactoryBot.define do
  factory :keylog do
    association :smartphone
    keystroke { 'hello' }
    app_package { 'com.example.app' }
    app_name { 'Example App' }
    event_type { 'TEXT_CHANGED' }
    device_id { smartphone&.device_id || 'test-device-001' }
    client_timestamp { 1705312800000 }
    session_id { 'session-001' }
  end
end
