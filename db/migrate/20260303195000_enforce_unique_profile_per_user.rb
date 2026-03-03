# frozen_string_literal: true

class EnforceUniqueProfilePerUser < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_profiles_on_user_id".freeze
  UNIQUE_INDEX_NAME = "index_profiles_on_user_id_unique".freeze

  def up
    duplicate_user_ids = select_values(<<~SQL.squish)
      SELECT user_id
      FROM profiles
      GROUP BY user_id
      HAVING COUNT(*) > 1
      LIMIT 5
    SQL

    if duplicate_user_ids.any?
      raise <<~MSG
        Cannot enforce unique profile per user: found duplicate profiles for user_id(s): #{duplicate_user_ids.join(", ")}.
        Resolve duplicates first, then rerun migration.
      MSG
    end

    remove_index :profiles, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :profiles, :user_id, unique: true, name: UNIQUE_INDEX_NAME, algorithm: :concurrently
  end

  def down
    remove_index :profiles, name: UNIQUE_INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :profiles, :user_id, name: INDEX_NAME, algorithm: :concurrently
  end
end
