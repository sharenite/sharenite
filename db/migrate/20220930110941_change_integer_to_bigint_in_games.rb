class ChangeIntegerToBigintInGames < ActiveRecord::Migration[7.0]
  def up
    change_column :games, :community_score, :bigint
    change_column :games, :critic_score, :bigint
    change_column :games, :user_score, :bigint
  end

  def down
    change_column :games, :community_score, :integer
    change_column :games, :critic_score, :integer
    change_column :games, :user_score, :integer
  end
end
