# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "profiles/profiles/index" do
  before do
    profile_one = create(:user).profile.tap { |profile| profile.update!(name: "Name", privacy: :public) }
    profile_two = create(:user).profile.tap { |profile| profile.update!(name: "Name", privacy: :public) }

    assign(:profiles, Profile.where(id: [profile_one.id, profile_two.id]).page(1))
    assign(:friendship_states_by_user_id, {})
    assign(:game_library_visibility_by_user_id, {})
    assign(:running_game_summary_by_user_id, {})
    assign(:current_user_id, nil)
    assign(:current_profile, nil)

    allow(view).to receive(:paginate).and_return("")
  end

  it "renders a list of profiles" do
    render
    assert_select "table tbody tr td", text: "Name".to_s, count: 2
  end

  it "renders the running game summary under the profile name when provided" do
    profile = Profile.first

    assign(:profiles, Profile.where(id: [profile.id]).page(1))
    assign(:running_game_summary_by_user_id, { profile.user_id => "Now playing: Balatro" })

    render

    expect(rendered).to include("Now playing: Balatro")
  end
end
