# frozen_string_literal: true

class AddFriendsPrivacyToProfiles < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      ALTER TYPE profile_privacy RENAME VALUE 'friendly' TO 'friends';
    SQL

    change_column_default :profiles, :privacy, from: "private", to: "friends"
    change_column_default :profiles, :game_library_privacy, from: "private", to: "friends"
    add_column :profiles, :friends_privacy, :profile_privacy, default: "friends", null: false
  end

  def down
    remove_column :profiles, :friends_privacy
    change_column_default :profiles, :game_library_privacy, from: "friends", to: "private"
    change_column_default :profiles, :privacy, from: "friends", to: "private"

    execute <<~SQL
      ALTER TYPE profile_privacy RENAME VALUE 'friends' TO 'friendly';
    SQL
  end
end
