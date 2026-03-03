# frozen_string_literal: true
FactoryBot.define do
  factory :profile do
    name { "MyString" }
    user do
      create(:user).tap do |new_user|
        new_user.profile.destroy!
      end
    end
  end
end
