# frozen_string_literal: true

FactoryBot.define do
  factory :playlist_item do
    playlist
    igdb_cache
    sequence(:order) { |n| n }
  end
end
