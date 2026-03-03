# frozen_string_literal: true

class AddAdminMarkerToUserDeletionEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :user_deletion_events, :scheduled_by_admin, :boolean, null: false, default: false
    add_column :user_deletion_events, :scheduled_by_admin_user_id, :uuid

    add_index :user_deletion_events, :scheduled_by_admin
    add_index :user_deletion_events, :scheduled_by_admin_user_id
    add_foreign_key :user_deletion_events, :admin_users, column: :scheduled_by_admin_user_id, on_delete: :nullify
  end
end
