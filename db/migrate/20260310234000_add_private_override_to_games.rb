# frozen_string_literal: true

class AddPrivateOverrideToGames < ActiveRecord::Migration[7.1]
  def change
    add_column :games, :private_override, :boolean, default: false, null: false
  end
end
