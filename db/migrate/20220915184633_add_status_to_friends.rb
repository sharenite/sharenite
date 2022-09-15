class AddStatusToFriends < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE TYPE invitation_status AS ENUM ('invited', 'accepted', 'declined');
    SQL
    add_column :friends, :status, :invitation_status, default: 'invited'
  end
  def down
    remove_column :friends, :status
    execute <<-SQL
      DROP TYPE invitation_status;
    SQL
  end
end
