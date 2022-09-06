class CreateJoinTableCategoryGame < ActiveRecord::Migration[7.0]
  def change
    create_join_table :games,
                      :categories,
                      column_options: {
                        null: false,
                        foreign_key: true,
                        type: :uuid
                      } do |t|
      t.index %i[game_id category_id]
      t.index %i[category_id game_id]
    end
  end
end
