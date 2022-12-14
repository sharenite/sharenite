class CreateJoinTableGameTag < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :tags,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id tag_id]
      t.index %i[tag_id game_id]
    end
  end
end
