class CreateJoinTableGamePlatform < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :platforms,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id platform_id]
      t.index %i[platform_id game_id]
    end
  end
end
