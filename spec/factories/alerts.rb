# frozen_string_literal: true

FactoryBot.define do
  factory :alert_rule do
    sequence(:name) { |n| "Alert Rule #{n}" }
    event_type { 'geofence_breach' }
    conditions { {} }
    notification_channels { ['email'] }
    enabled { true }
    cooldown_minutes { 60 }
    metadata { {} }
  end

  factory :alert do
    association :alert_rule
    association :device, factory: :apk_installation
    severity { 'medium' }
    sequence(:title) { |n| "Alert #{n}" }
    message { 'Test alert message' }
    metadata { {} }
    triggered_at { Time.utc(2025, 1, 15, 12, 0, 0) }
  end
end
