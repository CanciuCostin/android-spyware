require 'securerandom'

FactoryBot.define do
  factory :apk_payload do
    name { "payload_#{SecureRandom.hex(4)}" }
    destination_ip { '127.0.0.1' }
    destination_port { '8080' }
    forwarding_ip { '127.0.0.1' }
    forwarding_port { '8080' }
  end
end
