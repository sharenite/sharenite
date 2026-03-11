# frozen_string_literal: true

require "rails_helper"

RSpec.describe "profiles/playlists/playlists/index" do
  before do
    @profile = create(:user).profile
    @profile.update!(name: "Playlist Owner", privacy: :public, playlists_privacy: :public)

    assign(:profile, @profile)
    assign(:playlists, Kaminari.paginate_array([]).page(1))

    allow(view).to receive(:current_user).and_return(@profile.user)
    allow(view).to receive(:user_signed_in?).and_return(true)
  end

  it "renders the new playlist link for the current profile" do
    render

    expect(rendered).to include(new_profile_playlist_path(@profile))
    expect(rendered).to include("New playlist")
  end

  it "shows the Private column for the owner" do
    render

    expect(rendered).to include("Private")
    expect(rendered).not_to include("Private override")
  end

  it "hides the Private column for non-owners" do
    allow(view).to receive(:current_user).and_return(create(:user))

    render

    expect(rendered).not_to include("Private</th>")
    expect(rendered).not_to include("Private override")
    expect(rendered).not_to include("New playlist")
  end
end
