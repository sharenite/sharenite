class AddPlayniteIdToGames < ActiveRecord::Migration[7.0]
  def change
    add_column :games, :playnite_id, :uuid
  end
end
