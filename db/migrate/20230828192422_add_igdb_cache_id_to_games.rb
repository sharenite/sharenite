class AddIgdbCacheIdToGames < ActiveRecord::Migration[7.0]
  def change
    change_table :games, id: :uuid do |t|
      t.references :igdb_cache, foreign_key: true, type: :uuid
    end
  end
end
