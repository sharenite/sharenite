# frozen_string_literal: true

FactoryBot.define do
  factory :igdb_cache do
    sequence(:igdb_id) { |n| n + 1000 }
    sequence(:name) { |n| "IGDB Game #{n}" }
  end
end
