# frozen_string_literal: true

FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "Test123$" }
    password_confirmation { "Test123$" }
  end
end
