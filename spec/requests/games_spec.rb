# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games" do
  describe "GET /index" do
    it "redirects unauthenticated users to profiles list through profile access guard" do
      user = create(:user)
      get profile_games_path(user.profile)

      expect(response).to redirect_to(profiles_path)
    end
  end
end
