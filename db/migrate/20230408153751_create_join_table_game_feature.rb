class CreateJoinTableGameFeature < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :features,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id feature_id]
      t.index %i[feature_id game_id]
    end
  end
end
