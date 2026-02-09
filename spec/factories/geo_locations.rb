# frozen_string_literal: true

FactoryBot.define do
  factory :geo_location do
    association :smartphone
    sequence(:latitude) { |n| (40.0 + (n * 0.001)).round(6) }
    sequence(:longitude) { |n| (-74.0 + (n * 0.001)).round(6) }
    date { '2025-01-15 12:00:00' }
  end
end
