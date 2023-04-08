class CreateJoinTableGameAgeRating < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :age_ratings,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id age_rating_id]
      t.index %i[age_rating_id game_id]
    end
  end
end
