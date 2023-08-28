class CreatePlaylistItem < ActiveRecord::Migration[7.0]
  def change
    create_table :playlist_items, id: :uuid do |t|
      t.references :playlist, foreign_key: true, type: :uuid, null: false
      t.references :igdb_cache, foreign_key: true, type: :uuid, null: false
      t.integer :order, null: false

      t.timestamps
    end

    add_index :playlist_items, [:igdb_cache_id, :playlist_id], unique: true
    add_index :playlist_items, [:order, :playlist_id], unique: true
  end
end
