require 'securerandom'

FactoryBot.define do
  factory :pending_command do
    association :smartphone
    request_id { SecureRandom.uuid }
    command { 'get_contacts' }
    status { :pending }
  end
end
