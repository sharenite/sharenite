# frozen_string_literal: true

class AddSyncJobRollupIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :sync_jobs, [:created_at, :sync_batch_id], if_not_exists: true
    add_index :sync_jobs, [:sync_batch_id, :status], if_not_exists: true
    add_index :sync_jobs, [:created_at, :payload_chunk_index], if_not_exists: true
  end
end
