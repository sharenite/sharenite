class AddIndexToGames < ActiveRecord::Migration[7.0]
  def change
    add_index :games, [:user_id, :playnite_id], unique: true
  end
end
