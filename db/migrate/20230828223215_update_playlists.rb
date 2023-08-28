class UpdatePlaylists < ActiveRecord::Migration[7.0]
  def change
    change_table :playlists, id: :uuid do |t|
      t.boolean :public, default: false, null: false
      t.references :user, null: false, foreign_key: true, type: :uuid
    end
  end
end