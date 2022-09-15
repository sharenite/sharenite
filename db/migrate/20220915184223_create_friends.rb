class CreateFriends < ActiveRecord::Migration[7.0]
  def change
    create_table :friends, id: :uuid do |t|
      t.references :inviter, null: false, foreign_key: {to_table: :users}, type: :uuid
      t.references :invitee, null: false, foreign_key: {to_table: :users}, type: :uuid

      t.timestamps
    end
  end
end
