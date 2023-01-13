class AddSyncJobStatuses < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      ALTER TYPE job_status ADD VALUE 'dead';
      ALTER TYPE job_status ADD VALUE 'failed';
    SQL
  end
end
