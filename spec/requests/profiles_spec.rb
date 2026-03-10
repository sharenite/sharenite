# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles requests", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "GET /profiles" do
    it "renders successfully for guests" do
      public_profile = create(:user).profile
      public_profile.update!(privacy: :public, name: "Public Name")
      friends_profile = create(:user).profile
      friends_profile.update!(privacy: :friends, name: "Friends Name")
      members_profile = create(:user).profile
      members_profile.update!(privacy: :members, name: "Members Name")

      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Public Name")
      expect(response.body).not_to include("Friends Name")
      expect(response.body).not_to include("Members Name")
    end

    it "does not list blocked profiles for the blocker" do
      viewer = create(:user)
      blocked_user = create(:user)
      blocked_user.profile.update!(privacy: :public, name: "Blocked Name")
      Friend.create!(inviter: viewer, invitee: blocked_user, status: :blocked)

      sign_in viewer
      get profiles_path

      expect(response.body).not_to include("Blocked Name")
    end

    it "does not list friends-only profiles for signed-in users who are not friends" do
      viewer = create(:user)
      hidden_user = create(:user)
      hidden_user.profile.update!(privacy: :friends, name: "Hidden Friends Profile")

      sign_in viewer
      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Hidden Friends Profile")
    end

    it "links invite-received states to the signed-in viewer friends page even without a vanity URL" do
      viewer = create(:user)
      inviter = create(:user)
      viewer.profile.update!(privacy: :public, vanity_url: nil)
      inviter.profile.update!(privacy: :public, name: "Inviter")
      Friend.create!(inviter:, invitee: viewer, status: :invited)

      sign_in viewer
      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(profile_friends_path(viewer.profile, tab: "received"))
    end

    it "shows the games count on community when the viewer is allowed to access the game library" do
      viewer = create(:user)
      owner = create(:user)
      owner.profile.update!(privacy: :members, game_library_privacy: :members, name: "Visible Library")
      owner.games.create!(name: "Community Visible Game")

      sign_in viewer
      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Library")
      expect(response.body).to include(profile_games_path(owner.profile))
      expect(response.body).to include("Games: 1")
      expect(response.body).not_to include("Visible Library</td>\n<td>\n<span class='profiles-info-pill profiles-info-pill-muted'>Hidden</span>")
    end
  end

  describe "GET /profiles/:id" do
    it "renders successfully for a public profile" do
      profile = create(:user).profile
      profile.update!(privacy: :public, name: "Visible Profile")

      get profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Profile")
    end

    it "redirects for a friends-only profile when viewer is not a friend" do
      profile = create(:user).profile
      profile.update!(privacy: :friends, name: "Friends Only")

      get profile_path(profile)

      expect(response).to redirect_to(profiles_path)
    end

    it "redirects for a blocked profile even when it is public" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, name: "Blocked Public")
      Friend.create!(inviter: owner, invitee: viewer, status: :blocked)

      sign_in viewer
      get profile_path(owner.profile)

      expect(response).to redirect_to(profiles_path)
    end

    it "lets a signed-in viewer block from another user's profile page" do
      viewer = create(:user)
      owner = create(:user)
      owner.profile.update!(privacy: :public, name: "Block Me")

      sign_in viewer
      post profile_block_profile_friend_path(owner.profile)

      expect(response).to redirect_to(profile_friends_path(viewer.profile, tab: "blocked"))
      relation = Friend.find_by(inviter: viewer, invitee: owner)
      expect(relation).to be_present
      expect(relation.status).to eq("blocked")
    end

    it "hides played games stats when gaming activity privacy blocks the viewer" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, game_library_privacy: :public, gaming_activity_privacy: :private)
      owner.games.create!(name: "Played Game", last_activity: Time.current)

      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Games")
      expect(response.body).not_to include("Played Games")
    end

    it "does not show privately overridden running games in the profile header for other viewers" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      owner.games.create!(name: "Visible Game", is_running: true, private_override: false)
      owner.games.create!(name: "Hidden Game", is_running: true, private_override: true)

      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now playing: Visible Game")
      expect(response.body).not_to include("Hidden Game")
      expect(response.body).not_to include("+1 more")
    end

    it "rejects editing another user's profile" do
      owner = create(:user)
      viewer = create(:user)
      sign_in viewer

      get edit_profile_path(owner.profile)

      expect(response).to redirect_to(profiles_path)
    end

    it "redirects back to the edit form after saving profile changes" do
      owner = create(:user)
      sign_in owner

      patch profile_path(owner.profile),
            params: { profile: { name: "Updated Name" } },
            as: :turbo_stream

      expect(response).to redirect_to(edit_profile_path(owner.profile))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit profile")
      expect(response.body).to include("Updated Name")
      expect(owner.profile.reload.name).to eq("Updated Name")
    end
  end

  describe "GET /profiles/:profile_id/friends" do
    it "renders accepted friends for an allowed public friends list" do
      owner = create(:user)
      friend_user = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      friend_user.profile.update!(privacy: :public, name: "Accepted Friend")
      Friend.create!(inviter: owner, invitee: friend_user, status: :accepted)

      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Accepted Friend")
      expect(response.body).not_to include("Received")
      expect(response.body).not_to include("Declined")
    end

    it "renders the owner friends page with tab collections" do
      owner = create(:user)
      inviter = create(:user)
      Friend.create!(inviter:, invitee: owner, status: :invited)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "friends")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Received")
    end

    it "does not render private accepted friends in the visible list" do
      owner = create(:user)
      private_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      private_friend.profile.update!(privacy: :private, name: "Hidden Friend")
      Friend.create!(inviter: owner, invitee: private_friend, status: :accepted)

      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Hidden Friend")
      expect(response.body).to include("Total friends listed: 0")
    end

    it "does not render friends-only accepted friends for unrelated signed-in viewers" do
      owner = create(:user)
      viewer = create(:user)
      hidden_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      hidden_friend.profile.update!(privacy: :friends, name: "Friends Only Friend")
      Friend.create!(inviter: owner, invitee: hidden_friend, status: :accepted)

      sign_in viewer
      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Friends Only Friend")
      expect(response.body).to include("Total friends listed: 0")
    end

    it "does not render blocked users in a visible friends list for the viewer" do
      owner = create(:user)
      viewer = create(:user)
      blocked_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      blocked_friend.profile.update!(privacy: :public, name: "Blocked Friend")
      Friend.create!(inviter: owner, invitee: blocked_friend, status: :accepted)
      Friend.create!(inviter: viewer, invitee: blocked_friend, status: :blocked)

      sign_in viewer
      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Blocked Friend")
      expect(response.body).to include("Total friends listed: 0")
    end

    it "hides game counts for friends whose library privacy blocks the viewer" do
      owner = create(:user)
      viewer = create(:user)
      hidden_library_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      hidden_library_friend.profile.update!(privacy: :public, game_library_privacy: :friends, name: "Hidden Library Friend")
      hidden_library_friend.games.create!(name: "Secret Game")
      Friend.create!(inviter: owner, invitee: hidden_library_friend, status: :accepted)

      sign_in viewer
      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hidden Library Friend")
      expect(response.body).to include("Hidden")
      expect(response.body).not_to include("Games: 1")
      expect(response.body).not_to include(profile_games_path(hidden_library_friend.profile))
    end

    it "ignores games count params when listing hidden-library friends" do
      owner = create(:user)
      viewer = create(:user)
      hidden_library_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      hidden_library_friend.profile.update!(privacy: :public, game_library_privacy: :friends, name: "Hidden Library Friend")
      hidden_library_friend.games.create!(name: "Secret Game")
      Friend.create!(inviter: owner, invitee: hidden_library_friend, status: :accepted)

      sign_in viewer
      get profile_friends_path(owner.profile, games_from: 1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hidden Library Friend")
      expect(response.body).to include("Total friends listed: 1")
    end

    it "ignores games count params when listing visible friends with zero games" do
      owner = create(:user)
      zero_games_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      zero_games_friend.profile.update!(privacy: :public, game_library_privacy: :public, name: "Zero Games Friend")
      Friend.create!(inviter: owner, invitee: zero_games_friend, status: :accepted)

      sign_in owner
      get profile_friends_path(owner.profile, games_from: 1)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody td.fw-semibold, .profiles-mobile-card .fw-semibold").map(&:text)
      expect(listed_names).to include("Zero Games Friend")
      expect(response.body).to include("Total friends listed: 1")
    end

    it "redirects when friends list privacy blocks access" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :private)

      get profile_friends_path(owner.profile)

      expect(response).to redirect_to(profiles_path)
    end

    it "rejects accepting another user's invitation through their profile route" do
      owner = create(:user)
      viewer = create(:user)
      inviter = create(:user)
      invitation = Friend.create!(inviter:, invitee: owner, status: :invited)

      sign_in viewer
      patch profile_accept_friend_path(owner.profile, id: invitation.id)

      expect(response).to redirect_to(profiles_path)
      expect(invitation.reload.status).to eq("invited")
    end

    it "rejects cancelling another user's sent invitation through their profile route" do
      owner = create(:user)
      viewer = create(:user)
      invitee = create(:user)
      invitation = Friend.create!(inviter: owner, invitee:, status: :invited)

      sign_in viewer
      delete profile_cancel_friend_path(owner.profile, id: invitation.id)

      expect(response).to redirect_to(profiles_path)
      expect(invitation.reload).to be_present
    end

    it "lets the owner unfriend from their own friends list" do
      owner = create(:user)
      friend_user = create(:user)
      relation = Friend.create!(inviter: owner, invitee: friend_user, status: :accepted)

      sign_in owner
      delete profile_unfriend_friend_path(owner.profile, id: relation.id)

      expect(response).to redirect_to(profile_friends_path(owner.profile, tab: "friends"))
      expect(Friend.where(id: relation.id)).to be_empty
    end

    it "lets the owner block an accepted friend and hides that profile afterward" do
      owner = create(:user)
      friend_user = create(:user)
      friend_user.profile.update!(privacy: :public, name: "Former Friend")
      relation = Friend.create!(inviter: owner, invitee: friend_user, status: :accepted)

      sign_in owner
      patch profile_block_friend_path(owner.profile, id: relation.id)

      expect(response).to redirect_to(profile_friends_path(owner.profile, tab: "blocked"))
      blocked_relation = Friend.find_by(inviter: owner, invitee: friend_user)
      expect(blocked_relation).to be_present
      expect(blocked_relation.status).to eq("blocked")

      get profiles_path
      expect(response.body).not_to include("Former Friend")
    end

    it "lets the owner unblock from the blocked tab" do
      owner = create(:user)
      blocked_user = create(:user)
      relation = Friend.create!(inviter: owner, invitee: blocked_user, status: :blocked)

      sign_in owner
      delete profile_unblock_friend_path(owner.profile, id: relation.id)

      expect(response).to redirect_to(profile_friends_path(owner.profile, tab: "blocked"))
      expect(Friend.where(id: relation.id)).to be_empty
    end
  end

  describe "GET /profiles/:profile_id/playlists" do
    it "marks My Playlists active in the main nav for owned playlist pages and item forms" do
      owner = create(:user)
      sign_in owner
      playlist = create(:playlist, user: owner, private_override: false)
      playlist_item = create(:playlist_item, playlist:, order: 1)

      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      playlists_link = document.at_css("a[href='#{profile_playlists_path(owner.profile)}']")
      expect(playlists_link).to be_present
      expect(playlists_link.text.strip).to eq("My Playlists")
      expect(playlists_link["class"]).to include("active")

      get edit_profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      playlists_link = document.at_css("a[href='#{profile_playlists_path(owner.profile)}']")
      expect(playlists_link["class"]).to include("active")

      get new_profile_playlist_playlist_item_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      playlists_link = document.at_css("a[href='#{profile_playlists_path(owner.profile)}']")
      expect(playlists_link["class"]).to include("active")

      get edit_profile_playlist_playlist_item_path(owner.profile, playlist, playlist_item)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      playlists_link = document.at_css("a[href='#{profile_playlists_path(owner.profile)}']")
      expect(playlists_link["class"]).to include("active")
    end

    it "redirects when playlist privacy blocks playlist access" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :private)

      get profile_playlists_path(owner.profile)

      expect(response).to redirect_to(profile_path(owner.profile))
    end

    it "shows playlists without a private override to an accepted friend when playlist privacy allows it" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :friends)
      playlist = create(:playlist, user: owner, name: "Friends Playlist", private_override: false)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)

      sign_in viewer
      get profile_playlists_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Friends Playlist")

      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Friends Playlist")
    end

    it "hides playlists with a private override from other allowed viewers" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :friends)
      playlist = create(:playlist, user: owner, name: "Private Override Playlist", private_override: true)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)

      sign_in viewer
      get profile_playlists_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Private Override Playlist")

      get profile_playlist_path(owner.profile, playlist)

      expect(response).to redirect_to(profile_playlists_path(owner.profile))
    end

    it "hides playlist owner actions for another viewer" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public)
      playlist = create(:playlist, user: owner, name: "Visible Playlist", private_override: false)
      create(:playlist_item, playlist:, order: 1)

      sign_in viewer
      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Playlist")
      expect(response.body).not_to include("Edit playlist")
      expect(response.body).not_to include("New item")
      expect(response.body).not_to include("Delete")
    end

    it "does not show owned playlist matches when the viewer cannot see the owner's library" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public, game_library_privacy: :private)
      playlist = create(:playlist, user: owner, name: "Visible Playlist", private_override: false)
      create(:playlist_item, playlist:, order: 1, igdb_cache: create(:igdb_cache, name: "Matched Game"))
      owner.games.create!(name: "Matched Game", igdb_cache: playlist.playlist_items.first.igdb_cache, private_override: false)

      sign_in viewer
      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Playlist")
      expect(response.body).not_to include("Owned matches")
      expect(response.body).not_to include("Statuses")
      expect(response.body).not_to include("Owned:")
    end

    it "shows only non-private owned playlist matches to allowed viewers" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public, game_library_privacy: :public)
      playlist = create(:playlist, user: owner, name: "Visible Playlist", private_override: false)
      igdb_cache = create(:igdb_cache, name: "Matched Game")
      create(:playlist_item, playlist:, order: 1, igdb_cache:)
      status = create(:completion_status, user: owner, name: "Completed")
      owner.games.create!(name: "Visible Match", igdb_cache:, private_override: false, completion_status: status)
      owner.games.create!(name: "Hidden Match", igdb_cache:, private_override: true, completion_status: status)

      sign_in viewer
      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      playlist_stats = document.css(".profiles-section-card .card-body").each_with_object({}) do |card, stats|
        label = card.at_css(".profiles-stat-label")&.text&.strip
        value = card.at_css(".profiles-stat-value")&.text&.strip
        stats[label] = value if label.present?
      end

      expect(playlist_stats["Owned matches"]).to eq("1")
      expect(playlist_stats["Statuses"]).to eq("1")
      expect(response.body).to include("Completed")
    end

    it "redirects back to the profile playlist index when the playlist is missing" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public)

      get profile_playlist_path(owner.profile, "missing-playlist")

      expect(response).to redirect_to(profile_playlists_path(owner.profile))
    end

    it "rejects editing another user's playlist" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public)
      playlist = create(:playlist, user: owner, private_override: false)

      sign_in viewer
      get edit_profile_playlist_path(owner.profile, playlist)

      expect(response).to redirect_to(profiles_path)
    end

    it "rejects creating a playlist for another user" do
      owner = create(:user)
      viewer = create(:user)
      sign_in viewer

      post profile_playlists_path(owner.profile), params: { playlist: { name: "Bad", private_override: "0" } }, as: :turbo_stream

      expect(response).to redirect_to(profiles_path)
      expect(owner.playlists.where(name: "Bad")).to be_empty
    end
  end

  describe "GET /profiles/new" do
    it "redirects guests to sign in" do
      get new_profile_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects signed-in users to profiles list because profile_id is required in current controller flow" do
      user = create(:user)
      sign_in user

      get new_profile_path

      expect(response).to redirect_to(profiles_path)
    end
  end

  describe "profile stats" do
    it "excludes privately overridden games from visible profile stats and activity" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, game_library_privacy: :friends, gaming_activity_privacy: :friends)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)
      owner.games.create!(name: "Visible Game", private_override: false, last_activity: 1.day.ago)
      owner.games.create!(name: "Hidden Game", private_override: true, last_activity: Time.current)

      sign_in viewer
      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(">1<")
      expect(response.body).to include("Visible Game")
      expect(response.body).not_to include("Hidden Game")
    end

    it "counts only playlists without a private override when playlist privacy allows the viewer" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :friends)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)
      create(:playlist, user: owner, private_override: false)
      create(:playlist, user: owner, private_override: true)

      sign_in viewer
      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Playlists")
      expect(response.body).to include(">1<")
    end

    it "counts privately overridden playlists for the owner" do
      owner = create(:user)
      sign_in owner
      create(:playlist, user: owner, private_override: false)
      create(:playlist, user: owner, private_override: true)

      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Playlists")
      expect(response.body).to include(">2<")
    end

    it "does not count blocked friends in the visible friends stat" do
      owner = create(:user)
      viewer = create(:user)
      visible_friend = create(:user)
      blocked_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public)
      visible_friend.profile.update!(privacy: :public)
      blocked_friend.profile.update!(privacy: :public)
      Friend.create!(inviter: owner, invitee: visible_friend, status: :accepted)
      Friend.create!(inviter: owner, invitee: blocked_friend, status: :accepted)
      Friend.create!(inviter: viewer, invitee: blocked_friend, status: :blocked)

      sign_in viewer
      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Friends")
      expect(response.body).to include(">1<")
      expect(response.body).not_to include(">2<")
    end
  end
end
