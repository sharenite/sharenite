class CreateSyncJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :sync_jobs, id: :uuid do |t|
      t.column :name, :string, null: false
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
