# frozen_string_literal: true

class CreateUserDeletionEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :user_deletion_events do |t|
      t.integer :status, null: false, default: 0
      t.datetime :requested_at, null: false
      t.datetime :job_started_at
      t.datetime :job_succeeded_at
      t.datetime :job_failed_at

      t.timestamps
    end

    add_index :user_deletion_events, :status
    add_index :user_deletion_events, :requested_at
    add_index :user_deletion_events, :job_succeeded_at
  end
end
