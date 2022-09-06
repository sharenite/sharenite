class CreatePlatforms < ActiveRecord::Migration[7.0]
  def change
    create_table :platforms, id: :uuid do |t|
      t.string :name
      t.uuid :playnite_id
      t.string :specification_id
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.timestamps

      t.index %i[user_id playnite_id], unique: true
    end
  end
end
