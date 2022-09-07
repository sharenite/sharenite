class GenerateProfilesForCurrentUsers < ActiveRecord::Migration[7.0]
  def change
    Profile.reset_column_information
    User.all.each { |user| Profile.create_or_find_by!(user: user) }
  end
end
