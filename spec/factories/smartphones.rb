require 'securerandom'

FactoryBot.define do
  factory :smartphone do
    association :apk_installation
    name { "Phone #{SecureRandom.hex(3)}" }
    device_id { "device-#{SecureRandom.hex(4)}" }
    operating_system { "Android 11" }
    is_rooted { false }
    is_app_hidden { false }
  end
end
