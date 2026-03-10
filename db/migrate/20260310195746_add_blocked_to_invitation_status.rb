# frozen_string_literal: true

class AddBlockedToInvitationStatus < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      ALTER TYPE invitation_status ADD VALUE IF NOT EXISTS 'blocked';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot remove values from a PostgreSQL enum safely."
  end
end
