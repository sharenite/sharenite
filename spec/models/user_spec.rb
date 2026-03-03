# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "profile lifecycle" do
    it "creates a profile automatically on user creation" do
      user = create(:user)

      expect(user.profile).to be_present
      expect(Profile.where(user_id: user.id).count).to eq(1)
    end
  end

  describe "deleting account" do
    it "becomes inactive for authentication when flagged for deletion" do
      user = create(:user)

      expect(user.active_for_authentication?).to be(true)

      user.update!(deleting: true, deletion_requested_at: Time.current, email: "#{user.id}@sharenite.link")
      expect(user.active_for_authentication?).to be(false)
      expect(user.inactive_message).to eq(:deleting)
    end
  end
end
