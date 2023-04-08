class CreateJoinTableGameRegion < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :regions,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id region_id]
      t.index %i[region_id game_id]
    end
  end
end
