# frozen_string_literal: true

# Adds concurrent indexes used by profile/friend/admin hot paths.
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :friends, [:status, :inviter_id], algorithm: :concurrently, if_not_exists: true
    add_index :friends, [:status, :invitee_id], algorithm: :concurrently, if_not_exists: true

    add_index :profiles, [:privacy, :name], algorithm: :concurrently, if_not_exists: true

    add_index :games, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :games, :last_activity, algorithm: :concurrently, if_not_exists: true
    add_index :games, [:user_id, :last_activity], algorithm: :concurrently, if_not_exists: true

    add_index :sync_jobs, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :sync_jobs, [:created_at, :status], algorithm: :concurrently, if_not_exists: true

    add_index :users, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :users, :confirmed_at, algorithm: :concurrently, if_not_exists: true
    add_index :users, :last_sign_in_at, algorithm: :concurrently, if_not_exists: true
  end
end
