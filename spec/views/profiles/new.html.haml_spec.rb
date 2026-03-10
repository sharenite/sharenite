# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "profiles/profiles/new" do
  before do
    user = create(:user)
    @profile = user.profile.tap { |profile| profile.update!(name: "MyString") }
    assign(:profile, @profile)
  end

  it "renders new profile form" do
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
