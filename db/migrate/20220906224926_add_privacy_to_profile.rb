class AddPrivacyToProfile < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE TYPE profile_privacy AS ENUM ('private', 'public', 'friendly');
    SQL
    add_column :profiles, :privacy, :profile_privacy, default: "private"
  end
  def down
    remove_column :profiles, :privacy
    execute <<-SQL
      DROP TYPE profile_privacy;
    SQL
  end
end
