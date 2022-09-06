class CreateCompletionStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :completion_statuses, id: :uuid do |t|
      t.string :name
      t.uuid :playnite_id
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
      t.index %i[user_id playnite_id], unique: true
    end

    change_table(:games) do |t|
      t.references :completion_status,
                   foreign_key: true,
                   type: :uuid,
                   null: true
    end
  end
end
