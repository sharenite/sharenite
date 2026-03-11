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

    it "shows visible in-game status on community and hides private activity" do
      viewer = create(:user)
      visible_owner = create(:user)
      hidden_owner = create(:user)

      visible_owner.profile.update!(privacy: :members, gaming_activity_privacy: :members, name: "Visible Activity")
      hidden_owner.profile.update!(privacy: :members, gaming_activity_privacy: :private, name: "Hidden Activity")
      visible_owner.games.create!(name: "Balatro", is_running: true, private_override: false)
      hidden_owner.games.create!(name: "Secret Game", is_running: true, private_override: false)

      sign_in viewer
      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Activity")
      expect(response.body).to include("Now playing: Balatro")
      expect(response.body).to include("Hidden Activity")
      expect(response.body).not_to include("Secret Game")
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

    it "shows the newer game activity in the profile header last active label" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Active Profile")
      owner.update_columns(last_sign_in_at: 5.days.ago, current_sign_in_at: 6.days.ago)
      owner.games.create!(name: "Recent Game", last_activity: 2.hours.ago, private_override: false)

      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Last active:")
      expect(response.body).to include("about 2 hours ago").or include("2 hours ago")
    end

    it "hides the profile header last active label when gaming activity privacy blocks the viewer" do
      owner = create(:user)
      owner.profile.update!(privacy: :public, gaming_activity_privacy: :private, name: "Private Activity")
      owner.update_columns(last_sign_in_at: 1.day.ago, current_sign_in_at: 2.days.ago)
      owner.games.create!(name: "Private Game", last_activity: 1.hour.ago, private_override: false)

      get profile_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Last active:")
      expect(response.body).to include("Hidden")
      expect(response.body).not_to include("1 hour ago")
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
      expect(response.body).not_to include("Friends since")
      expect(response.body).not_to include("friends_since_desc")
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

    it "preserves the active tab in the shared desktop search form" do
      owner = create(:user)
      inviter = create(:user)
      Friend.create!(inviter:, invitee: owner, status: :invited)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "received")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="tab"))
      expect(response.body).to include(%(value="received"))
    end

    it "keeps the desktop sort links wired to sync the shared search form state" do
      owner = create(:user)
      friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Friend A")
      Friend.create!(inviter: owner, invitee: friend, status: :accepted)

      sign_in owner
      get profile_friends_path(owner.profile, sort: "name_asc")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("click-&gt;search-form#syncStateFromLink").or include("click->search-form#syncStateFromLink")
    end

    it "shows friendship and invitation timestamps across tabs" do
      owner = create(:user)
      accepted_friend = create(:user)
      inviter = create(:user)
      sent_invitee = create(:user)
      declined_user = create(:user)
      blocked_user = create(:user)

      accepted_relation = Friend.create!(inviter: owner, invitee: accepted_friend, status: :accepted)
      accepted_relation.update_column(:updated_at, 3.days.ago)
      received_relation = Friend.create!(inviter:, invitee: owner, status: :invited)
      received_relation.update_column(:created_at, 2.days.ago)
      sent_relation = Friend.create!(inviter: owner, invitee: sent_invitee, status: :invited)
      sent_relation.update_column(:created_at, 4.days.ago)
      declined_relation = Friend.create!(inviter: owner, invitee: declined_user, status: :declined)
      declined_relation.update_column(:updated_at, 5.days.ago)
      blocked_relation = Friend.create!(inviter: owner, invitee: blocked_user, status: :blocked)
      blocked_relation.update_column(:created_at, 6.days.ago)

      sign_in owner

      get profile_friends_path(owner.profile, tab: "friends")
      expect(response.body).to include("Friends since")

      get profile_friends_path(owner.profile, tab: "received")
      expect(response.body).to include("Sent")

      get profile_friends_path(owner.profile, tab: "sent")
      expect(response.body).to include("Sent")

      get profile_friends_path(owner.profile, tab: "declined")
      expect(response.body).to include("Declined")

      get profile_friends_path(owner.profile, tab: "blocked")
      expect(response.body).to include("Blocked since")
    end

    it "does not expose other users' emails when profile names are blank" do
      owner = create(:user)
      inviter = create(:user, email: "secret-inviter@example.test")
      inviter.profile.update!(name: nil, privacy: :public)
      Friend.create!(inviter:, invitee: owner, status: :invited)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "received")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Unknown user")
      expect(response.body).not_to include("secret-inviter@example.test")
    end

    it "sorts received invitations by sent timestamp" do
      owner = create(:user)
      older_inviter = create(:user)
      newer_inviter = create(:user)
      older_inviter.profile.update!(name: "Older Inviter", privacy: :public)
      newer_inviter.profile.update!(name: "Newer Inviter", privacy: :public)

      older_relation = Friend.create!(inviter: older_inviter, invitee: owner, status: :invited)
      older_relation.update_column(:created_at, 5.days.ago)
      newer_relation = Friend.create!(inviter: newer_inviter, invitee: owner, status: :invited)
      newer_relation.update_column(:created_at, 1.day.ago)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "received", sort: "sent_desc")

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody tr td .fw-semibold").map { |node| node.text.strip }
      expect(listed_names.first(2)).to eq(["Newer Inviter", "Older Inviter"])
    end

    it "sorts blocked users by blocked timestamp" do
      owner = create(:user)
      older_blocked = create(:user)
      newer_blocked = create(:user)
      older_blocked.profile.update!(name: "Older Blocked", privacy: :public)
      newer_blocked.profile.update!(name: "Newer Blocked", privacy: :public)

      older_relation = Friend.create!(inviter: owner, invitee: older_blocked, status: :blocked)
      older_relation.update_column(:created_at, 4.days.ago)
      newer_relation = Friend.create!(inviter: owner, invitee: newer_blocked, status: :blocked)
      newer_relation.update_column(:created_at, 1.day.ago)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "blocked", sort: "blocked_desc")

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody tr td .fw-semibold").map { |node| node.text.strip }
      expect(listed_names.first(2)).to eq(["Newer Blocked", "Older Blocked"])
    end

    it "preserves the active search filter in mobile sort forms" do
      owner = create(:user)
      inviter = create(:user)
      owner.profile.update!(name: "Owner Profile")
      inviter.profile.update!(name: "Searchable Friend")
      Friend.create!(inviter:, invitee: owner, status: :invited)

      sign_in owner
      get profile_friends_path(owner.profile, tab: "received", search_name: "Search")

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      search_name_inputs = document.css('input[name="search_name"][value="Search"]')
      expect(search_name_inputs.count).to be >= 2
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
      listed_names = document.css(".profiles-table tbody td .fw-semibold, .profiles-mobile-card .fw-semibold").map(&:text)
      expect(listed_names).to include("Zero Games Friend")
      expect(response.body).to include("Total friends listed: 1")
    end

    it "shows privacy-aware last active values in the friends list" do
      owner = create(:user)
      visible_friend = create(:user)
      hidden_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      visible_friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Visible Activity Friend")
      hidden_friend.profile.update!(privacy: :public, gaming_activity_privacy: :private, name: "Hidden Activity Friend")
      visible_friend.update_columns(last_sign_in_at: 3.days.ago, current_sign_in_at: 4.days.ago)
      hidden_friend.update_columns(last_sign_in_at: 2.days.ago, current_sign_in_at: 3.days.ago)
      visible_friend.games.create!(name: "Recent Game", last_activity: 30.minutes.ago, private_override: false)
      hidden_friend.games.create!(name: "Private Game", last_activity: 10.minutes.ago, private_override: false)
      Friend.create!(inviter: owner, invitee: visible_friend, status: :accepted)
      Friend.create!(inviter: owner, invitee: hidden_friend, status: :accepted)

      get profile_friends_path(owner.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Activity Friend")
      expect(response.body).to include("Hidden Activity Friend")
      expect(response.body).to include("Last active")
      expect(response.body).to include("30 minutes ago").or include("about 1 hour ago")
      expect(response.body).to include("Hidden")
    end

    it "shows visible in-game statuses across owner tabs and hides blocked activity by privacy" do
      owner = create(:user)
      received_user = create(:user)
      sent_user = create(:user)
      declined_user = create(:user)
      blocked_user = create(:user)

      received_user.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Received Active")
      sent_user.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Sent Active")
      declined_user.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Declined Active")
      blocked_user.profile.update!(privacy: :public, gaming_activity_privacy: :private, name: "Blocked Hidden")

      received_user.games.create!(name: "Received Game", is_running: true, private_override: false)
      sent_user.games.create!(name: "Sent Game", is_running: true, private_override: false)
      declined_user.games.create!(name: "Declined Game", is_running: true, private_override: false)
      blocked_user.games.create!(name: "Blocked Game", is_running: true, private_override: false)

      Friend.create!(inviter: received_user, invitee: owner, status: :invited)
      Friend.create!(inviter: owner, invitee: sent_user, status: :invited)
      Friend.create!(inviter: owner, invitee: declined_user, status: :declined)
      Friend.create!(inviter: owner, invitee: blocked_user, status: :blocked)

      sign_in owner

      get profile_friends_path(owner.profile, tab: "received")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now playing: Received Game")

      get profile_friends_path(owner.profile, tab: "sent")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now playing: Sent Game")

      get profile_friends_path(owner.profile, tab: "declined")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now playing: Declined Game")

      get profile_friends_path(owner.profile, tab: "blocked")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blocked Hidden")
      expect(response.body).not_to include("Blocked Game")
    end

    it "sorts friends by privacy-aware last active descending by default" do
      owner = create(:user)
      older_friend = create(:user)
      newer_friend = create(:user)
      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      older_friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Older Friend")
      newer_friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Newer Friend")
      older_friend.update_columns(last_sign_in_at: 10.days.ago, current_sign_in_at: 11.days.ago)
      newer_friend.update_columns(last_sign_in_at: 10.days.ago, current_sign_in_at: 11.days.ago)
      older_friend.games.create!(name: "Older Game", last_activity: 2.days.ago, private_override: false)
      newer_friend.games.create!(name: "Newer Game", last_activity: 1.hour.ago, private_override: false)
      Friend.create!(inviter: owner, invitee: older_friend, status: :accepted)
      Friend.create!(inviter: owner, invitee: newer_friend, status: :accepted)

      get profile_friends_path(owner.profile, sort: "last_active_desc")

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody tr td .fw-semibold").map { |node| node.text.strip }
      expect(listed_names.first(2)).to eq(["Newer Friend", "Older Friend"])
    end

    it "ignores friends-since sorting for non-owners" do
      owner = create(:user)
      viewer = create(:user)
      recent_friend = create(:user)
      older_friend = create(:user)

      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      recent_friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Recent Activity Friend")
      older_friend.profile.update!(privacy: :public, gaming_activity_privacy: :public, name: "Older Activity Friend")

      recent_friend.update_columns(last_sign_in_at: 10.days.ago, current_sign_in_at: 11.days.ago)
      older_friend.update_columns(last_sign_in_at: 10.days.ago, current_sign_in_at: 11.days.ago)
      recent_friend.games.create!(name: "Recent Game", last_activity: 1.hour.ago, private_override: false)
      older_friend.games.create!(name: "Older Game", last_activity: 2.days.ago, private_override: false)

      older_relation = Friend.create!(inviter: owner, invitee: older_friend, status: :accepted)
      older_relation.update_column(:updated_at, 1.hour.ago)
      recent_relation = Friend.create!(inviter: owner, invitee: recent_friend, status: :accepted)
      recent_relation.update_column(:updated_at, 10.days.ago)

      sign_in viewer
      get profile_friends_path(owner.profile, sort: "friends_since_desc")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Friends since")
      expect(response.body).not_to include("friends_since_desc")
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody tr td .fw-semibold").map { |node| node.text.strip }
      expect(listed_names.first(2)).to eq(["Recent Activity Friend", "Older Activity Friend"])
    end

    it "keeps hidden games rows at the end when sorting by games" do
      owner = create(:user)
      visible_low = create(:user)
      hidden_mid = create(:user)
      visible_high = create(:user)

      owner.profile.update!(privacy: :public, friends_privacy: :public, name: "Owner Profile")
      visible_low.profile.update!(privacy: :public, game_library_privacy: :public, name: "Visible Low")
      hidden_mid.profile.update!(privacy: :public, game_library_privacy: :friends, name: "Hidden Mid")
      visible_high.profile.update!(privacy: :public, game_library_privacy: :public, name: "Visible High")

      visible_low.games.create!(name: "Game 1")
      hidden_mid.games.create!(name: "Game 1")
      hidden_mid.games.create!(name: "Game 2")
      visible_high.games.create!(name: "Game 1")
      visible_high.games.create!(name: "Game 2")
      visible_high.games.create!(name: "Game 3")

      Friend.create!(inviter: owner, invitee: visible_low, status: :accepted)
      Friend.create!(inviter: owner, invitee: hidden_mid, status: :accepted)
      Friend.create!(inviter: owner, invitee: visible_high, status: :accepted)

      get profile_friends_path(owner.profile, sort: "games_asc")

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      listed_names = document.css(".profiles-table tbody tr td .fw-semibold").map { |node| node.text.strip }
      expect(listed_names.first(3)).to eq(["Visible Low", "Visible High", "Hidden Mid"])
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
