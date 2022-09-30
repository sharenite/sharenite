class ChangeIntegerToBigintInGames < ActiveRecord::Migration[7.0]
  def change
    change_column :games, :community_score, :bigint
    change_column :games, :critic_score, :bigint
    change_column :games, :user_score, :bigint
  end
end
