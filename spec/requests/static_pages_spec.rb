# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StaticPages" do
  include Devise::Test::IntegrationHelpers

  describe "GET /" do
    it "renders landing page for guests" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /static_pages/dashboard" do
    it "redirects guests to sign in" do
      get static_pages_dashboard_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders dashboard for signed-in users" do
      user = create(:user)
      sign_in user

      get static_pages_dashboard_path

      expect(response).to redirect_to(profile_path(user.profile))
    end
  end
end
