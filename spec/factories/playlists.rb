# frozen_string_literal: true

FactoryBot.define do
  factory :playlist do
    user
    sequence(:name) { |n| "Playlist #{n}" }
    public { true }
  end
end
