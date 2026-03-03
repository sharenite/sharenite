# frozen_string_literal: true

class AddAdminEmailToUserDeletionEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :user_deletion_events, :scheduled_by_admin_email, :string
    add_index :user_deletion_events, :scheduled_by_admin_email
  end
end
