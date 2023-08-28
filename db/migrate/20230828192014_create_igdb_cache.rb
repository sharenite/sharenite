class CreateIgdbCache < ActiveRecord::Migration[7.0]
  def change
    create_table :igdb_caches, id: :uuid do |t|
      t.integer :igdb_id, unique: true, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :igdb_caches, :igdb_id, unique: true
  end
end
