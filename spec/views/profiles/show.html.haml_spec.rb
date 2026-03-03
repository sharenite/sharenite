# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "profiles/profiles/show" do
  before do
    profile = create(:user).profile
    profile.update!(name: "Name", vanity_url: "name-profile", privacy: :public, game_library_privacy: :public)
    assign(:profile, profile)
    assign(:profile_stats, { games_count: 0, playlists_count: 0, active_friends_count: 0, pending_received_count: 0 })
    assign(:current_user_id, nil)
    assign(:current_profile, nil)
    assign(:friendship_state, nil)
    allow(view).to receive(:user_signed_in?).and_return(false)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Profile details/)
  end
end
