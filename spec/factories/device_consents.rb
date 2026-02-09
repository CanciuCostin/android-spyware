# frozen_string_literal: true

FactoryBot.define do
  factory :device_consent do
    association :device, factory: :apk_installation
    consent_type { 'device_monitoring' }
    granted { false }
    granted_at { nil }
    revoked_at { nil }
    granted_by { nil }
    ip_address { nil }
    consent_text { nil }
    consent_version { '1.0' }

    trait :granted do
      granted { true }
      granted_at { Time.utc(2025, 1, 10, 12, 0, 0) }
      granted_by { 'admin@test.com' }
      ip_address { '127.0.0.1' }
      consent_text { 'Consent for device monitoring' }
    end

    trait :revoked do
      granted { false }
      granted_at { Time.utc(2025, 1, 10, 12, 0, 0) }
      revoked_at { Time.utc(2025, 1, 12, 12, 0, 0) }
      granted_by { 'admin@test.com' }
    end

    trait :location_tracking do
      consent_type { 'location_tracking' }
    end

    trait :microphone_access do
      consent_type { 'microphone_access' }
    end

    trait :camera_access do
      consent_type { 'camera_access' }
    end

    trait :sms_monitoring do
      consent_type { 'sms_monitoring' }
    end

    trait :data_collection do
      consent_type { 'data_collection' }
    end

    trait :call_logging do
      consent_type { 'call_logging' }
    end
  end
end
