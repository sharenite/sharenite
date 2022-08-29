class AddStatusToSyncJobs < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE TYPE job_status AS ENUM ('queued', 'running', 'finished');
    SQL
    add_column :sync_jobs, :status, :job_status, default: 'queued'
  end
  def down
    remove_column :sync_jobs, :status
    execute <<-SQL
      DROP TYPE job_status;
    SQL
  end
end
