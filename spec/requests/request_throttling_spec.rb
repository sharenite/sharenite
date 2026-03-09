# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Request throttling", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  class FakeRedis
    def initialize
      @values = {}
      @expirations = {}
    end

    def get(key)
      cleanup!(key)
      @values[key]
    end

    def set(key, value, ex: nil)
      @values[key] = value
      @expirations[key] = Time.current + ex if ex
      value
    end

    def incr(key)
      cleanup!(key)
      @values[key] = @values.fetch(key, 0).to_i + 1
    end

    def expire(key, ttl)
      cleanup!(key)
      return false unless @values.key?(key)

      @expirations[key] = Time.current + ttl
      true
    end

    def ttl(key)
      cleanup!(key)
      expires_at = @expirations[key]
      return -1 if expires_at.blank?

      remaining = (expires_at - Time.current).ceil
      remaining.positive? ? remaining : -2
    end

    def del(key)
      @values.delete(key)
      @expirations.delete(key)
    end

    private

    def cleanup!(key)
      expires_at = @expirations[key]
      return if expires_at.blank? || expires_at > Time.current

      @values.delete(key)
      @expirations.delete(key)
    end
  end

  around do |example|
    original_redis = $redis
    $redis = FakeRedis.new
    travel_to(Time.zone.parse("2026-03-09 12:00:00")) { example.run }
  ensure
    $redis = original_redis
  end

  let(:user) { create(:user) }

  describe "authenticated API requests" do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_API_AUTH_LIMIT", anything).and_return("2")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_API_AUTH_PERIOD", anything).and_return("60")
      reset_request_throttling_rules!
      sign_in user
    end

    after do
      reset_request_throttling_rules!
    end

    it "throttles and then automatically lifts the limit window" do
      2.times { get "/api/v1/games" }
      get "/api/v1/games"

      expect(response).to have_http_status(:too_many_requests)
      expect(RequestThrottleEvent.throttle_events.count).to eq(1)
      expect(RequestThrottleEvent.current.count).to eq(1)

      travel 61.seconds
      get "/api/v1/games"

      expect(response).to have_http_status(:ok)
      expect(RequestThrottleEvent.current.count).to eq(0)
    end
  end

  describe "unauthenticated auth requests" do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_AUTH_GUEST_LIMIT", anything).and_return("1")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_AUTH_GUEST_PERIOD", anything).and_return("60")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", anything).and_return("2")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", anything).and_return((1.hour.to_i).to_s)
      reset_request_throttling_rules!
    end

    after do
      reset_request_throttling_rules!
    end

    it "throttles repeated hits to devise endpoints" do
      get "/users/sign_in"
      expect(response).to have_http_status(:ok)

      get "/users/sign_in"
      expect(response).to have_http_status(:too_many_requests)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Too Many Requests")
      expect(RequestThrottleEvent.throttle_events.where(rule_name: "auth_unauthenticated").count).to eq(1)
    end
  end

  describe "unauthenticated web requests" do
    let(:profile_owner) { create(:user) }
    let!(:game) { profile_owner.games.create!(name: "Rate Limited Game") }

    before do
      profile_owner.profile.update!(privacy: :public, game_library_privacy: :public)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_WEB_SHOW_GUEST_LIMIT", anything).and_return("1")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_WEB_SHOW_GUEST_PERIOD", anything).and_return("60")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", anything).and_return("2")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", anything).and_return((1.hour.to_i).to_s)
      reset_request_throttling_rules!
      host! "www.example.com"
    end

    after do
      reset_request_throttling_rules!
    end

    it "escalates repeated guest throttles into a permanent IP block" do
      path = "/profiles/#{profile_owner.profile.id}/games/#{game.id}"

      get path
      expect(response).to have_http_status(:ok)

      get path
      expect(response).to have_http_status(:too_many_requests)
      expect(RequestThrottleEvent.throttle_events.count).to eq(1)

      travel 61.seconds
      get path
      expect(response).to have_http_status(:ok)

      get path
      expect(response).to have_http_status(:forbidden)
      expect(RequestThrottleEvent.block_events.permanent_blocks.count).to eq(1)

      get path
      expect(response).to have_http_status(:forbidden)
      expect(RequestThrottleEvent.current.block_events.count).to eq(1)
    end

    it "applies a slow guest browsing window to profile and game pages only" do
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_PUBLIC_PROFILE_BROWSE_GUEST_LIMIT", anything).and_return("2")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_PUBLIC_PROFILE_BROWSE_GUEST_PERIOD", anything).and_return(1.day.to_i.to_s)
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_WEB_SHOW_GUEST_LIMIT", anything).and_return("100")
      allow(ENV).to receive(:fetch).with("REQUEST_THROTTLE_GLOBAL_GUEST_LIMIT", anything).and_return("100")
      reset_request_throttling_rules!

      get "/profiles"
      expect(response).to have_http_status(:ok)

      get "/profiles/#{profile_owner.profile.id}/games/#{game.id}"
      expect(response).to have_http_status(:ok)

      get "/profiles/#{profile_owner.profile.id}/games"
      expect(response).to have_http_status(:too_many_requests)
      expect(RequestThrottleEvent.throttle_events.where(rule_name: "public_profile_browse_unauthenticated_slow").count).to eq(1)
    end
  end

  describe "admin visibility" do
    let(:admin_user) { create(:admin_user) }

    it "shows current and historical incidents in ActiveAdmin" do
      RequestThrottleEvent.create!(
        event_type: "throttle",
        rule_name: "api_games_authenticated",
        actor_type: "user",
        actor_key: "user:#{user.id}",
        user: user,
        ip_address: "127.0.0.1",
        request_method: "GET",
        request_path: "/api/v1/games",
        limit_value: 24,
        period_seconds: 60,
        hit_count: 1,
        peak_count: 25,
        started_at: 1.minute.ago,
        last_seen_at: 30.seconds.ago,
        expires_at: 30.seconds.from_now
      )
      RequestThrottleEvent.create!(
        event_type: "block",
        rule_name: "api_games_unauthenticated",
        actor_type: "ip",
        actor_key: "ip:192.0.2.1",
        ip_address: "192.0.2.1",
        request_method: "GET",
        request_path: "/api/v1/games",
        limit_value: 8,
        period_seconds: 60,
        hit_count: 3,
        peak_count: 12,
        started_at: 2.days.ago,
        last_seen_at: 2.days.ago,
        expires_at: 1.day.ago
      )

      sign_in admin_user

      get "/admin/request_throttle_events"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("api_games_authenticated")

      get "/admin/request_throttle_events?scope=historical"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("192.0.2.1")
    end

    it "allows admins to add and lift manual IP blocks" do
      sign_in admin_user

      post "/admin/request_throttle_events/manual_block", params: { ip_address: "203.0.113.50" }
      expect(response).to redirect_to("/admin/request_throttle_events")
      expect(RequestThrottling.active_permanent_blocked?("203.0.113.50")).to be(true)

      event = RequestThrottleEvent.find_by!(rule_name: "manual_admin_block", ip_address: "203.0.113.50")
      put "/admin/request_throttle_events/#{event.id}/lift"

      expect(response).to redirect_to("/admin/request_throttle_events/#{event.id}")
      expect(RequestThrottling.active_permanent_blocked?("203.0.113.50")).to be(false)
      expect(event.reload.lifted_at).to be_present
    end
  end

  def reset_request_throttling_rules!
    %i[
      @authenticated_api_rule
      @unauthenticated_api_rule
      @authenticated_global_rule
      @unauthenticated_global_rule
      @authenticated_auth_rule
      @unauthenticated_auth_rule
      @authenticated_web_index_rule
      @unauthenticated_web_index_rule
      @authenticated_web_show_rule
      @unauthenticated_web_show_rule
      @unauthenticated_public_profile_browse_slow_rule
    ].each do |ivar|
      RequestThrottling.instance_variable_set(ivar, nil)
    end
  end
end
