# frozen_string_literal: true

# Adds a counter cache column for user-owned games.
class AddGamesCountToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :games_count, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE users
      SET games_count = counts.games_count
      FROM (
        SELECT user_id, COUNT(*)::integer AS games_count
        FROM games
        GROUP BY user_id
      ) counts
      WHERE counts.user_id = users.id
    SQL
  end

  def down
    remove_column :users, :games_count
  end
end
