# frozen_string_literal: true

FactoryBot.define do
  factory :file_transfer do
    association :smartphone
    sequence(:upload_id) { |n| format('a1b2c3d4-e5f6-7890-abcd-%012d', n) }
    filename { 'test_file.txt' }
    total_chunks { 3 }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end
  end
end
