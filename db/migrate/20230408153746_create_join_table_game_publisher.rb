class CreateJoinTableGamePublisher < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :publishers,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id publisher_id]
      t.index %i[publisher_id game_id]
    end
  end
end
