require 'securerandom'

FactoryBot.define do
  factory :apk_installation do
    association :apk_payload
    target_ip { "device-#{SecureRandom.hex(3)}" }
    status { 'pending' }
  end
end
