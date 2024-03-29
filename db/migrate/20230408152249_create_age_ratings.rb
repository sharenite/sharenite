class CreateAgeRatings < ActiveRecord::Migration[7.0]
  def change
    create_table :age_ratings, id: :uuid do |t|
      t.string :name
      t.uuid :playnite_id
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
