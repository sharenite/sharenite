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

    it "rejects editing another user's profile" do
      owner = create(:user)
      viewer = create(:user)
      sign_in viewer

      get edit_profile_path(owner.profile)

      expect(response).to redirect_to(profiles_path)
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
    it "redirects when playlist privacy blocks playlist access" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :private)

      get profile_playlists_path(owner.profile)

      expect(response).to redirect_to(profile_path(owner.profile))
    end

    it "shows non-public playlists to an accepted friend when playlist privacy allows it" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :friends)
      playlist = create(:playlist, user: owner, name: "Friends Playlist", public: false)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)

      sign_in viewer
      get profile_playlists_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Friends Playlist")

      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Friends Playlist")
    end

    it "hides playlist owner actions for another viewer" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :public)
      playlist = create(:playlist, user: owner, name: "Visible Playlist", public: true)
      create(:playlist_item, playlist:, order: 1)

      sign_in viewer
      get profile_playlist_path(owner.profile, playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Playlist")
      expect(response.body).not_to include("Edit playlist")
      expect(response.body).not_to include("New item")
      expect(response.body).not_to include("Delete")
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
      playlist = create(:playlist, user: owner, public: true)

      sign_in viewer
      get edit_profile_playlist_path(owner.profile, playlist)

      expect(response).to redirect_to(profiles_path)
    end

    it "rejects creating a playlist for another user" do
      owner = create(:user)
      viewer = create(:user)
      sign_in viewer

      post profile_playlists_path(owner.profile), params: { playlist: { name: "Bad", public: true } }, as: :turbo_stream

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
    it "counts all playlists when playlist privacy allows the viewer" do
      owner = create(:user)
      viewer = create(:user)
      owner.profile.update!(privacy: :public, playlists_privacy: :friends)
      Friend.create!(inviter: owner, invitee: viewer, status: :accepted)
      create(:playlist, user: owner, public: true)
      create(:playlist, user: owner, public: false)

      sign_in viewer
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
