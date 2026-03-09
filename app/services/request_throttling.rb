# frozen_string_literal: true

module RequestThrottling
  Rule = Struct.new(
    :name,
    :limit,
    :period,
    :actor_type,
    :escalates_to_permanent_block,
    :escalation_threshold,
    :escalation_period,
    keyword_init: true
  )

  Actor = Struct.new(:type, :key, :user, :ip_address, keyword_init: true) do
    def authenticated?
      type == "user"
    end
  end

  Decision = Struct.new(:status, :rule, :actor, :retry_after, :limit, :count, keyword_init: true) do
    def allowed?
      status == :allow
    end

    def throttled?
      status == :throttle
    end

    def blocked?
      status == :block
    end
  end

  module_function

  def rules_for(request, actor:)
    return [] if ignored_path?(request.path)

    applicable_rules = []
    applicable_rules << auth_rule(actor) if auth_path?(request.path)
    applicable_rules << games_rule(request.path, actor)
    applicable_rules << global_rule(actor)
    applicable_rules.compact
  end

  def build_actor(request, env)
    user = env["warden"]&.user(:user)
    ip_address = request.remote_ip.to_s.presence || "unknown"
    return Actor.new(type: "ip", key: "ip:#{ip_address}", ip_address: ip_address) if user.blank?

    Actor.new(type: "user", key: "user:#{user.id}", user: user, ip_address: ip_address)
  end

  def active_permanent_blocked?(ip_address)
    redis.get(permanent_block_key(ip_address)).present?
  rescue StandardError => e
    Rails.logger.error("[request_throttling] permanent block lookup failed: #{e.class}: #{e.message}")
    false
  end

  def lift_permanent_block!(event)
    return false unless event.permanent? && event.actor_type == "ip"

    redis.del(permanent_block_key(event.ip_address))
    event.update!(lifted_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[request_throttling] block lift failed: #{e.class}: #{e.message}")
    false
  end

  def redis
    $redis
  end

  def authenticated_api_rule
    @authenticated_api_rule ||= Rule.new(
      name: "api_games_authenticated",
      limit: env_int("REQUEST_THROTTLE_API_AUTH_LIMIT", 120),
      period: env_int("REQUEST_THROTTLE_API_AUTH_PERIOD", 60),
      actor_type: "user",
      escalates_to_permanent_block: false,
      escalation_threshold: 0,
      escalation_period: 0
    )
  end

  def authenticated_global_rule
    @authenticated_global_rule ||= Rule.new(
      name: "global_authenticated",
      limit: env_int("REQUEST_THROTTLE_GLOBAL_AUTH_LIMIT", 300),
      period: env_int("REQUEST_THROTTLE_GLOBAL_AUTH_PERIOD", 60),
      actor_type: "user",
      escalates_to_permanent_block: false,
      escalation_threshold: 0,
      escalation_period: 0
    )
  end

  def unauthenticated_global_rule
    @unauthenticated_global_rule ||= Rule.new(
      name: "global_unauthenticated",
      limit: env_int("REQUEST_THROTTLE_GLOBAL_GUEST_LIMIT", 120),
      period: env_int("REQUEST_THROTTLE_GLOBAL_GUEST_PERIOD", 60),
      actor_type: "ip",
      escalates_to_permanent_block: true,
      escalation_threshold: env_int("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", 10),
      escalation_period: env_int("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", 24.hours.to_i)
    )
  end

  def authenticated_auth_rule
    @authenticated_auth_rule ||= Rule.new(
      name: "auth_authenticated",
      limit: env_int("REQUEST_THROTTLE_AUTH_AUTH_LIMIT", 30),
      period: env_int("REQUEST_THROTTLE_AUTH_AUTH_PERIOD", 60),
      actor_type: "user",
      escalates_to_permanent_block: false,
      escalation_threshold: 0,
      escalation_period: 0
    )
  end

  def unauthenticated_auth_rule
    @unauthenticated_auth_rule ||= Rule.new(
      name: "auth_unauthenticated",
      limit: env_int("REQUEST_THROTTLE_AUTH_GUEST_LIMIT", 20),
      period: env_int("REQUEST_THROTTLE_AUTH_GUEST_PERIOD", 60),
      actor_type: "ip",
      escalates_to_permanent_block: true,
      escalation_threshold: env_int("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", 10),
      escalation_period: env_int("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", 24.hours.to_i)
    )
  end

  def unauthenticated_api_rule
    @unauthenticated_api_rule ||= Rule.new(
      name: "api_games_unauthenticated",
      limit: env_int("REQUEST_THROTTLE_API_GUEST_LIMIT", 8),
      period: env_int("REQUEST_THROTTLE_API_GUEST_PERIOD", 60),
      actor_type: "ip",
      escalates_to_permanent_block: true,
      escalation_threshold: env_int("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", 10),
      escalation_period: env_int("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", 24.hours.to_i)
    )
  end

  def authenticated_web_index_rule
    @authenticated_web_index_rule ||= Rule.new(
      name: "profile_games_index_authenticated",
      limit: env_int("REQUEST_THROTTLE_WEB_INDEX_AUTH_LIMIT", 60),
      period: env_int("REQUEST_THROTTLE_WEB_INDEX_AUTH_PERIOD", 60),
      actor_type: "user",
      escalates_to_permanent_block: false,
      escalation_threshold: 0,
      escalation_period: 0
    )
  end

  def unauthenticated_web_index_rule
    @unauthenticated_web_index_rule ||= Rule.new(
      name: "profile_games_index_unauthenticated",
      limit: env_int("REQUEST_THROTTLE_WEB_INDEX_GUEST_LIMIT", 15),
      period: env_int("REQUEST_THROTTLE_WEB_INDEX_GUEST_PERIOD", 60),
      actor_type: "ip",
      escalates_to_permanent_block: true,
      escalation_threshold: env_int("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", 10),
      escalation_period: env_int("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", 24.hours.to_i)
    )
  end

  def authenticated_web_show_rule
    @authenticated_web_show_rule ||= Rule.new(
      name: "profile_games_show_authenticated",
      limit: env_int("REQUEST_THROTTLE_WEB_SHOW_AUTH_LIMIT", 120),
      period: env_int("REQUEST_THROTTLE_WEB_SHOW_AUTH_PERIOD", 60),
      actor_type: "user",
      escalates_to_permanent_block: false,
      escalation_threshold: 0,
      escalation_period: 0
    )
  end

  def unauthenticated_web_show_rule
    @unauthenticated_web_show_rule ||= Rule.new(
      name: "profile_games_show_unauthenticated",
      limit: env_int("REQUEST_THROTTLE_WEB_SHOW_GUEST_LIMIT", 30),
      period: env_int("REQUEST_THROTTLE_WEB_SHOW_GUEST_PERIOD", 60),
      actor_type: "ip",
      escalates_to_permanent_block: true,
      escalation_threshold: env_int("REQUEST_THROTTLE_GUEST_BLOCK_THRESHOLD", 10),
      escalation_period: env_int("REQUEST_THROTTLE_GUEST_BLOCK_PERIOD", 24.hours.to_i)
    )
  end

  def env_int(name, fallback)
    Integer(ENV.fetch(name, fallback))
  rescue ArgumentError, TypeError
    fallback
  end

  def auth_path?(path)
    path.start_with?("/users/sign_in", "/users/sign_up", "/users/password", "/users/confirmation", "/users/unlock")
  end

  def ignored_path?(path)
    path == "/up" || path.start_with?("/assets", "/packs", "/admin", "/karafka", "/rails/active_storage")
  end

  def games_rule(path, actor)
    case path
    when %r{\A/api/v1/games(?:/delete)?\z}, %r{\A/api/v1/games/[^/]+\z}
      actor.authenticated? ? authenticated_api_rule : unauthenticated_api_rule
    when %r{\A/profiles/[^/]+/games\z}
      actor.authenticated? ? authenticated_web_index_rule : unauthenticated_web_index_rule
    when %r{\A/profiles/[^/]+/games/[^/]+\z}
      actor.authenticated? ? authenticated_web_show_rule : unauthenticated_web_show_rule
    end
  end

  def auth_rule(actor)
    actor.authenticated? ? authenticated_auth_rule : unauthenticated_auth_rule
  end

  def global_rule(actor)
    actor.authenticated? ? authenticated_global_rule : unauthenticated_global_rule
  end

  class Limiter
    def initialize(request:, env:)
      @request = request
      @env = env
      @actor = RequestThrottling.build_actor(request, env)
      @rules = RequestThrottling.rules_for(request, actor: actor)
    end

    def call
      return allow unless rules.any?
      return blocked(fallback_rule) if blocked_ip?

      rules.each do |active_rule|
        count = RequestThrottling.redis.incr(counter_key(active_rule))
        RequestThrottling.redis.expire(counter_key(active_rule), active_rule.period) if count == 1
        retry_after = normalized_ttl(RequestThrottling.redis.ttl(counter_key(active_rule)), active_rule)

        next if count <= active_rule.limit

        return block_from_escalation(active_rule, count) if escalate_to_permanent_block?(active_rule, count)

        log_throttle(active_rule, count, retry_after) if count == active_rule.limit + 1
        return throttle(active_rule, count, retry_after)
      end

      allow
    rescue StandardError => e
      Rails.logger.error("[request_throttling] limiter failure: #{e.class}: #{e.message}")
      allow
    end

    private

    attr_reader :request, :env, :actor, :rules

    def blocked_ip?
      actor.type == "ip" && RequestThrottling.active_permanent_blocked?(actor.ip_address)
    end

    def fallback_rule
      rules.first || RequestThrottling.unauthenticated_global_rule
    end

    def escalate_to_permanent_block?(rule, count)
      return false unless actor.type == "ip"
      return false unless rule.escalates_to_permanent_block
      return false unless count == rule.limit + 1

      escalation_value = RequestThrottling.redis.incr(escalation_key(rule))
      RequestThrottling.redis.expire(escalation_key(rule), rule.escalation_period) if escalation_value == 1
      escalation_value >= rule.escalation_threshold
    end

    def block_from_escalation(rule, count)
      RequestThrottling.redis.set(RequestThrottling.permanent_block_key(actor.ip_address), Time.current.iso8601)
      log_block(rule, count)
      blocked(rule)
    end

    def log_throttle(rule, count, retry_after)
      upsert_event!(
        rule: rule,
        event_type: "throttle",
        count: count,
        expires_at: Time.current + retry_after,
        escalation_value: current_escalation_value(rule)
      )
    end

    def log_block(rule, count)
      upsert_event!(
        rule: rule,
        event_type: "block",
        count: count,
        expires_at: nil,
        escalation_value: current_escalation_value(rule),
        permanent: true
      )
    end

    def current_escalation_value(rule)
      return unless actor.type == "ip"

      RequestThrottling.redis.get(escalation_key(rule)).to_i
    rescue StandardError
      nil
    end

    def upsert_event!(rule:, event_type:, count:, expires_at:, escalation_value:, permanent: false)
      now = Time.current
      event = RequestThrottleEvent.where(
        event_type: event_type,
        rule_name: rule.name,
        actor_key: actor.key,
        request_method: request.request_method,
        request_path: request.path,
        permanent: permanent,
        lifted_at: nil
      ).order(last_seen_at: :desc).first

      if event&.current?(now)
        event.update!(
          last_seen_at: now,
          hit_count: event.hit_count + 1,
          peak_count: [event.peak_count, count].max,
          escalation_value: escalation_value || event.escalation_value
        )
        return event
      end

      RequestThrottleEvent.create!(
        event_type: event_type,
        rule_name: rule.name,
        actor_type: actor.type,
        actor_key: actor.key,
        user: actor.user,
        ip_address: actor.ip_address,
        request_method: request.request_method,
        request_path: request.path,
        limit_value: rule.limit,
        period_seconds: rule.period,
        hit_count: 1,
        peak_count: count,
        escalation_value: escalation_value,
        permanent: permanent,
        started_at: now,
        last_seen_at: now,
        expires_at: expires_at
      )
    end

    def counter_key(rule)
      "request_throttling:counter:#{rule.name}:#{actor.key}"
    end

    def escalation_key(rule)
      "request_throttling:escalation:#{rule.name}:#{actor.ip_address}"
    end

    def normalized_ttl(ttl, rule)
      ttl.positive? ? ttl : rule.period
    end

    def allow(count: 0)
      Decision.new(status: :allow, rule: fallback_rule, actor: actor, retry_after: 0, limit: fallback_rule&.limit, count: count)
    end

    def throttle(rule, count, retry_after)
      Decision.new(status: :throttle, rule: rule, actor: actor, retry_after: retry_after, limit: rule.limit, count: count)
    end

    def blocked(rule)
      Decision.new(status: :block, rule: rule, actor: actor, retry_after: 0, limit: rule.limit, count: rule.limit)
    end
  end

  def permanent_block_key(ip_address)
    "request_throttling:blocked_ip:#{ip_address}"
  end

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      decision = Limiter.new(request: request, env: env).call
      return @app.call(env) if decision.allowed?

      rate_limited_response(request: request, decision: decision)
    end

    private

    attr_reader :app

    def rate_limited_response(request:, decision:)
      status = decision.blocked? ? 403 : 429
      body = if request.path.start_with?("/api/")
               {
                 error: decision.blocked? ? "Request blocked" : "Rate limit exceeded",
                 retry_after: decision.retry_after,
                 limit: decision.limit,
                 rule: decision.rule.name
               }.to_json
             else
               [html_error_page(status)]
             end

      headers = {
        "Retry-After" => decision.retry_after.to_s,
        "X-RateLimit-Limit" => decision.limit.to_s,
        "X-RateLimit-Rule" => decision.rule.name
      }
      headers["Content-Type"] = request.path.start_with?("/api/") ? "application/json" : "text/html; charset=utf-8"

      [status, headers, body]
    end

    def html_error_page(status)
      Rails.public_path.join("#{status}.html").read
    rescue StandardError
      "<html><body><h1>#{status}</h1></body></html>"
    end
  end
end
