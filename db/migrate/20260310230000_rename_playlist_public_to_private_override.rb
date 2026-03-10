# frozen_string_literal: true

class RenamePlaylistPublicToPrivateOverride < ActiveRecord::Migration[7.1]
  def up
    rename_column :playlists, :public, :private_override

    execute <<~SQL
      UPDATE playlists
      SET private_override = NOT private_override;
    SQL
  end

  def down
    execute <<~SQL
      UPDATE playlists
      SET private_override = NOT private_override;
    SQL

    rename_column :playlists, :private_override, :public
  end
end
