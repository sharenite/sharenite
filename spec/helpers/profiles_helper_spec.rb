# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ProfilesHelper do
  describe "#profile_running_game_summary" do
    it "returns a single running game label when activity is visible" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.games.create!(name: "Hades", is_running: true)

      expect(helper.profile_running_game_summary(user.profile, nil)).to eq("Now playing: Hades")
    end

    it "collapses multiple running games into a short summary" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.games.create!(name: "Balatro", is_running: true)
      user.games.create!(name: "Hades", is_running: true)

      expect(helper.profile_running_game_summary(user.profile, nil)).to eq("Now playing: Balatro +1 more")
    end

    it "returns nil when activity visibility is blocked" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :private)
      user.games.create!(name: "Hades", is_running: true)

      expect(helper.profile_running_game_summary(user.profile, nil)).to be_nil
    end

    it "excludes privately overridden running games for non-owners" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.games.create!(name: "Balatro", is_running: true, private_override: false)
      user.games.create!(name: "Hades", is_running: true, private_override: true)

      expect(helper.profile_running_game_summary(user.profile, nil)).to eq("Now playing: Balatro")
    end

    it "includes privately overridden running games for the owner" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.games.create!(name: "Balatro", is_running: true, private_override: false)
      user.games.create!(name: "Hades", is_running: true, private_override: true)

      expect(helper.profile_running_game_summary(user.profile, user)).to eq("Now playing: Balatro +1 more")
    end
  end

  describe "#profile_last_active_at" do
    it "returns the newer value between sign-in and visible game activity" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.update_columns(last_sign_in_at: 3.days.ago, current_sign_in_at: 5.days.ago)
      user.games.create!(name: "Balatro", last_activity: 1.day.ago, private_override: false)

      expect(helper.profile_last_active_at(user.profile, nil)).to be_within(1.second).of(1.day.ago)
    end

    it "returns nil when gaming activity visibility is blocked" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :private)
      user.update_columns(last_sign_in_at: 1.day.ago, current_sign_in_at: 2.days.ago)
      user.games.create!(name: "Balatro", last_activity: Time.current, private_override: false)

      expect(helper.profile_last_active_at(user.profile, nil)).to be_nil
      expect(helper.profile_last_active_label(user.profile, nil)).to eq("Hidden")
    end

    it "returns Never when activity is visible but no activity timestamps exist" do
      user = create(:user)
      user.profile.update!(privacy: :public, gaming_activity_privacy: :public)
      user.update_columns(last_sign_in_at: nil, current_sign_in_at: nil)

      expect(helper.profile_last_active_label(user.profile, nil)).to eq("Never")
    end
  end

  describe "#profile_friendship_state_label" do
    it "returns a human-readable label for known states" do
      expect(helper.profile_friendship_state_label(:friends)).to eq("Friends")
      expect(helper.profile_friendship_state_label("invite_received")).to eq("Invite received")
    end

    it "returns nil for unknown states" do
      expect(helper.profile_friendship_state_label(:unknown)).to be_nil
    end
  end

  describe "#profile_friendship_state_class" do
    it "returns expected class names for known states" do
      expect(helper.profile_friendship_state_class(:friends)).to eq("profiles-info-pill profiles-info-pill-success")
      expect(helper.profile_friendship_state_class(:invite_sent)).to eq("profiles-info-pill profiles-info-pill-info")
      expect(helper.profile_friendship_state_class(:you_declined)).to eq("profiles-info-pill profiles-info-pill-muted")
    end

    it "returns default class for unknown states" do
      expect(helper.profile_friendship_state_class(:unknown)).to eq("profiles-info-pill")
    end
  end
end
