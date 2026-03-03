# frozen_string_literal: true

class AddAsyncDeletionFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :deleting, :boolean, null: false, default: false
    add_column :users, :deletion_requested_at, :datetime
    add_index :users, :deleting
  end
end
