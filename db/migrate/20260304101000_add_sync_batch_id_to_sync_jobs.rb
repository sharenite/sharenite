# frozen_string_literal: true

class AddSyncBatchIdToSyncJobs < ActiveRecord::Migration[7.1]
  def change
    add_column :sync_jobs, :sync_batch_id, :uuid
    add_index :sync_jobs, :sync_batch_id
  end
end
