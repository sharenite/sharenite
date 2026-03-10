# frozen_string_literal: true

class AddGamingActivityPrivacyToProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :profiles, :gaming_activity_privacy, :profile_privacy, default: "friends", null: false
  end
end
