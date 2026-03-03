# frozen_string_literal: true

class AddGamesCountToSyncJobs < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:sync_jobs, :games_count)

    add_column :sync_jobs, :games_count, :integer
    add_index :sync_jobs, :games_count
  end
end
