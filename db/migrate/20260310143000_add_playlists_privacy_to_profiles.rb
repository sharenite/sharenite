# frozen_string_literal: true

class AddPlaylistsPrivacyToProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :profiles, :playlists_privacy, :profile_privacy, default: "friends", null: false
  end
end
