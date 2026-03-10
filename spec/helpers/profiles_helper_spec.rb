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
