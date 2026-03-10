# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Profile do
  it "belongs to user and enforces unique profile per user" do
    user = create(:user)
    existing_profile = user.profile

    duplicate_profile = described_class.new(user:, name: "Duplicate profile")
    expect(duplicate_profile).not_to be_valid
    expect(duplicate_profile.errors[:user_id]).to be_present

    expect(existing_profile.user).to eq(user)
  end

  it "defines privacy enums" do
    expect(described_class.privacies.keys).to include("private", "friends", "members", "public")
    expect(described_class.game_library_privacies.keys).to include("private", "friends", "members", "public")
    expect(described_class.gaming_activity_privacies.keys).to include("private", "friends", "members", "public")
    expect(described_class.playlists_privacies.keys).to include("private", "friends", "members", "public")
    expect(described_class.friends_privacies.keys).to include("private", "friends", "members", "public")
  end

  it "is not visible to a blocked viewer even when public" do
    owner = create(:user)
    viewer = create(:user)
    owner.profile.update!(privacy: :public)
    Friend.create!(inviter: viewer, invitee: owner, status: :blocked)

    expect(owner.profile.visible_to?(viewer)).to be(false)
    expect(owner.profile.friends_with?(viewer)).to be(false)
  end
end
