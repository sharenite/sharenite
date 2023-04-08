class CreateJoinTableGameSeries < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :series,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id series_id]
      t.index %i[series_id game_id]
    end
  end
end
