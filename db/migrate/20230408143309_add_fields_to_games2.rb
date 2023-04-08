class AddFieldsToGames2 < ActiveRecord::Migration[7.0]
  def change
    change_table(:games) do |t|
      t.column :enable_system_hdr, :boolean
      t.column :install_size, :bigint
      t.column :last_size_scan_date, :datetime
      t.column :override_install_state, :boolean
      t.column :recent_activity, :datetime
    end    
  end
end
