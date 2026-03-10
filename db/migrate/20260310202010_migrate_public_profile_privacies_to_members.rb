# frozen_string_literal: true

class MigratePublicProfilePrivaciesToMembers < ActiveRecord::Migration[7.1]
  PRIVACY_COLUMNS = %i[
    privacy
    game_library_privacy
    gaming_activity_privacy
    playlists_privacy
    friends_privacy
  ].freeze

  def up
    PRIVACY_COLUMNS.each do |column|
      execute <<~SQL
        UPDATE profiles
        SET #{column} = 'members'
        WHERE #{column} = 'public';
      SQL
    end
  end

  def down
    PRIVACY_COLUMNS.each do |column|
      execute <<~SQL
        UPDATE profiles
        SET #{column} = 'public'
        WHERE #{column} = 'members';
      SQL
    end
  end
end
