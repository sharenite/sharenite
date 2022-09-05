class CreateJoinTableGameTag < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games, :tags, column_options: { type: :uuid } do |t|
      t.references :games, index: true, foreign_key: true, type: :uuid
      t.references :tags, index: true, foreign_key: true, type: :uuid
    end
  end
end
