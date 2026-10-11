# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API authentication", type: :request do
  let(:user) { create(:user) }
  let(:api_headers) { { "ACCEPT" => "application/json" } }

  def log_in(user, password: "Test123$", remember_me: "0")
    post "/users/sign_in", params: { user: { email: user.email, password:, remember_me: } }
  end

  it "rejects anonymous requests to the mounted API" do
    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["Location"]).to be_nil
  end

  it "uses the browser login cookie for Playnite API requests" do
    log_in(user)
    expect(response).to have_http_status(:see_other)

    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id" => user.id, "email" => user.email)
    expect(response.parsed_body).not_to have_key("encrypted_password")
  end

  it "rejects an incorrect password" do
    log_in(user, password: "incorrect")
    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects an unconfirmed account" do
    user.update!(confirmed_at: nil)
    log_in(user)
    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a deleting account even if its session was already authenticated" do
    log_in(user)
    user.update!(deleting: true)
    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "restores API authentication from the remember-me cookie" do
    log_in(user, remember_me: "1")
    expect(cookies["remember_user_token"]).to be_present
    cookies.delete(Rails.application.config.session_options.fetch(:key))

    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("id")).to eq(user.id)
  end

  it "ends API access when the user signs out" do
    log_in(user, remember_me: "1")
    delete "/users/sign_out"
    expect(cookies["remember_user_token"]).to be_blank

    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not use an admin session to authenticate a user API request" do
    admin = create(:admin_user)
    post "/admin/login", params: { admin_user: { email: admin.email, password: "Test123$" } }
    expect(response).to have_http_status(:see_other)

    get "/api/v1/users/me", headers: api_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not allow a user session to access ActiveAdmin" do
    log_in(user)
    get "/admin"

    expect(response).to redirect_to("/admin/login")
  end
end
