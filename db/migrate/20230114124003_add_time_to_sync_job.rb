class AddTimeToSyncJob < ActiveRecord::Migration[7.0]
  def change
    add_column :sync_jobs, :started_processing_at, :datetime
    add_column :sync_jobs, :finished_processing_at, :datetime
    add_column :sync_jobs, :waiting_time, :integer
    add_column :sync_jobs, :processing_time, :integer
  end
end
