class CreateJoinTableGameGenre < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :genres,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id genre_id]
      t.index %i[genre_id game_id]
    end
  end
end
