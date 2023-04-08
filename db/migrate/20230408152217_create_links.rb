class CreateLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :links, id: :uuid do |t|
      t.string :name
      t.string :url
      t.references :game, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
