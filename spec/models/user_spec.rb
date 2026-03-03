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
end
