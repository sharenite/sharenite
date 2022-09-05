class AddIndexToTags < ActiveRecord::Migration[7.0]
  def change
    add_column :tags, :playnite_id, :uuid
    add_index :tags, %i[user_id playnite_id], unique: true
  end
end
