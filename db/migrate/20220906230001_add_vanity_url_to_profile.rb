class AddVanityUrlToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :vanity_url, :string, null: true, unique: true
    add_index :profiles, :vanity_url, unique: true
  end
end
