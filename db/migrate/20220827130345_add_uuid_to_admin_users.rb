class AddUuidToAdminUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :admin_users, :uuid, :uuid, default: "gen_random_uuid()", null: false
    rename_column :admin_users, :id, :integer_id
    rename_column :admin_users, :uuid, :id
    execute "ALTER TABLE admin_users drop constraint admin_users_pkey;"
    execute "ALTER TABLE admin_users ADD PRIMARY KEY (id);"

    # Optionally you remove auto-incremented
    # default value for integer_id column
    execute "ALTER TABLE ONLY admin_users ALTER COLUMN integer_id DROP DEFAULT;"
    change_column_null :admin_users, :integer_id, true
    execute "DROP SEQUENCE IF EXISTS admin_users_id_seq"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
