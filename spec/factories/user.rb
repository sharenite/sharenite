# frozen_string_literal: true

FactoryBot.define do
  factory(:user) do
    email { Faker::Internet.email }
    password { "Test123$" }
    confirmed_at { Faker::Date.backward(days: 14) }
  end
end
