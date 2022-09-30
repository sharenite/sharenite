class ChangeBigintToUnsignedInGames < ActiveRecord::Migration[7.0]
  def up
    change_column :games, :community_score, :integer
    change_column :games, :critic_score, :integer
    change_column :games, :user_score, :integer
    change_column :games, :play_count, :decimal, :precision => 20, :scale => 0
    change_column :games, :playtime, :decimal, :precision => 20, :scale => 0
  end

  def down
    change_column :games, :community_score, :bigint
    change_column :games, :critic_score, :bigint
    change_column :games, :user_score, :bigint
    change_column :games, :play_count, :bigint
    change_column :games, :playtime, :bigint
  end
end
