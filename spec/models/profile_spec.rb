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
    expect(described_class.privacies.keys).to include("private", "public", "friendly")
    expect(described_class.game_library_privacies.keys).to include("private", "public", "friendly")
  end
end
