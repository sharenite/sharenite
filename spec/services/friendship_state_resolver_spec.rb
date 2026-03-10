# frozen_string_literal: true

require "rails_helper"

RSpec.describe FriendshipStateResolver do
  describe ".states_for_users" do
    it "prefers blocked states over accepted friendships when conflicting rows exist" do
      current_user = create(:user)
      other_user = create(:user)
      Friend.create!(inviter: current_user, invitee: other_user, status: :accepted)
      Friend.create!(inviter: other_user, invitee: current_user, status: :blocked)

      result = described_class.states_for_users(
        current_user_id: current_user.id,
        user_ids: [other_user.id]
      )

      expect(result[other_user.id]).to eq(:blocked_you)
    end
  end
end
