# frozen_string_literal: true
require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe "profiles/profiles/edit" do
  before do
    user = create(:user)
    @profile = assign(:profile, user.profile.tap { |profile| profile.update!(name: "MyString") })
  end

  it "renders the edit profile form" do
    render

    assert_select "form[action=?][method=?]", profile_path(@profile), "post" do
      assert_select "input[name=?]", "profile[name]"
      assert_select "input[name=?]", "profile[vanity_url]"
      assert_select "select[name=?]", "profile[privacy]"
      assert_select "select[name=?]", "profile[game_library_privacy]"
      assert_select "select[name=?]", "profile[gaming_activity_privacy]"
      assert_select "select[name=?]", "profile[playlists_privacy]"
      assert_select "select[name=?]", "profile[friends_privacy]"
    end
  end
end
# rubocop:enable all
