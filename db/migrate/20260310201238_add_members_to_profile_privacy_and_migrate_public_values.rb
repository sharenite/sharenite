# frozen_string_literal: true

class AddMembersToProfilePrivacyAndMigratePublicValues < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      ALTER TYPE profile_privacy ADD VALUE IF NOT EXISTS 'members';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely remove PostgreSQL enum values."
  end
end
