class CreateJoinTableGameDeveloper < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :developers,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id developer_id]
      t.index %i[developer_id game_id]
    end
  end
end
