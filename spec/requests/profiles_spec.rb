# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles requests", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "GET /profiles" do
    it "renders successfully for guests" do
      public_profile = create(:user).profile
      public_profile.update!(privacy: :public, name: "Public Name")

      get profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Public Name")
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
end
