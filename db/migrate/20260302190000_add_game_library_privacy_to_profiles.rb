# frozen_string_literal: true

# Splits profile visibility into basic profile privacy and games library privacy.
class AddGameLibraryPrivacyToProfiles < ActiveRecord::Migration[7.1]
  def up
    add_column :profiles, :game_library_privacy, :profile_privacy, default: "private", null: false
    execute <<~SQL.squish
      UPDATE profiles
      SET game_library_privacy = privacy
      WHERE game_library_privacy IS NULL OR game_library_privacy = 'private'
    SQL
  end

  def down
    remove_column :profiles, :game_library_privacy
  end
end
