class AddFieldsToGames < ActiveRecord::Migration[7.0]
  def change
    change_table(:games) do |t|
      t.column :added, :datetime
      t.column :community_score, :integer
      t.column :critic_score, :integer
      t.column :description, :text
      t.column :favorite, :boolean
      t.column :game_id, :string
      t.column :game_started_script, :text
      t.column :hidden, :boolean
      t.column :include_library_plugin_action, :boolean
      t.column :install_directory, :string
      t.column :is_custom_game, :boolean
      t.column :is_installed, :boolean
      t.column :is_installing, :boolean
      t.column :is_launching, :boolean
      t.column :is_running, :boolean
      t.column :is_uninstalling, :boolean
      t.column :last_activity, :datetime
      t.column :manual, :string
      t.column :modified, :datetime
      t.column :notes, :text
      t.column :play_count, :bigint
      t.column :playtime, :bigint
      t.column :plugin_id, :uuid
      t.column :post_script, :text
      t.column :pre_script, :text
      t.column :release_date, :date
      t.column :sorting_name, :string
      t.column :use_global_game_started_script, :boolean
      t.column :use_global_post_script, :boolean
      t.column :use_global_pre_script, :boolean
      t.column :user_score, :integer
      t.column :version, :string
    end    
  end
end
