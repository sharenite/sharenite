class AddIndexToFriends < ActiveRecord::Migration[7.0]
  def change
    add_index :games, [:playnite_id, :user_id], unique: true

    add_index :friends, [:invitee_id, :inviter_id], unique: true
    add_index :friends, [:inviter_id, :invitee_id], unique: true
  end
end
