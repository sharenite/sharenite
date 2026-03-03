# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  include Devise::Test::IntegrationHelpers

  it "schedules account deletion instead of immediate destroy" do
    user = create(:user, email: "self-delete@sharenite.local")
    sign_in user

    delete user_registration_path

    expect(response).to redirect_to(root_path)

    user.reload
    expect(user.deleting).to be(true)
    expect(user.email).to eq("#{user.id}@sharenite.link")
    expect(user.deletion_requested_at).to be_present
  end
end
