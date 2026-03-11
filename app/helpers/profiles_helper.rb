# frozen_string_literal: true
# Profiles helper
# rubocop:disable Metrics/ModuleLength
module ProfilesHelper
  PRIVACY_OPTIONS = [
    ["Public", "public"],
    ["Members", "members"],
    ["Friends only", "friends"],
    ["Private", "private"]
  ].freeze

  GAME_ACTIVITY_STATES = [
    { predicate: :is_running?, label: "Running", tone: :playing },
    { predicate: :is_launching?, label: "Launching", tone: :launching },
    { predicate: :is_installing?, label: "Installing", tone: :installing },
    { predicate: :is_uninstalling?, label: "Uninstalling", tone: :uninstalling }
  ].freeze
  FRIENDS_SORT_OPTIONS = {
    "friends" => [
      ["Last active (Newest first)", "last_active_desc"],
      ["Last active (Oldest first)", "last_active_asc"],
      ["Friends since (Newest first)", "friends_since_desc"],
      ["Friends since (Oldest first)", "friends_since_asc"],
      ["Name (A-Z)", "name_asc"],
      ["Name (Z-A)", "name_desc"],
      ["Games (Highest first)", "games_desc"],
      ["Games (Lowest first)", "games_asc"]
    ],
    "received" => [
      ["Received (Newest first)", "sent_desc"],
      ["Received (Oldest first)", "sent_asc"],
      ["Name (A-Z)", "name_asc"],
      ["Name (Z-A)", "name_desc"]
    ],
    "sent" => [
      ["Sent (Newest first)", "sent_desc"],
      ["Sent (Oldest first)", "sent_asc"],
      ["Name (A-Z)", "name_asc"],
      ["Name (Z-A)", "name_desc"]
    ],
    "declined" => [
      ["Declined (Newest first)", "declined_desc"],
      ["Declined (Oldest first)", "declined_asc"],
      ["Name (A-Z)", "name_asc"],
      ["Name (Z-A)", "name_desc"],
      ["Status (A-Z)", "status_asc"],
      ["Status (Z-A)", "status_desc"]
    ],
    "blocked" => [
      ["Blocked (Newest first)", "blocked_desc"],
      ["Blocked (Oldest first)", "blocked_asc"],
      ["Name (A-Z)", "name_asc"],
      ["Name (Z-A)", "name_desc"]
    ]
  }.freeze

  def profile_privacy_options
    PRIVACY_OPTIONS
  end

  def profile_privacy_label(value)
    {
      "public" => "Public",
      "members" => "Members",
      "friends" => "Friends only",
      "private" => "Private"
    }.fetch(value.to_s, value.to_s.humanize)
  end

  def game_activity_labels(game)
    game_activity_states(game).pluck(:label)
  end

  def game_activity_states(game)
    GAME_ACTIVITY_STATES.select { |state| game.public_send(state[:predicate]) }
  end

  def profile_activity_pill_class(tone)
    "profiles-activity-pill profiles-activity-pill--#{tone}"
  end

  def game_activity_pill_class(tone)
    "games-activity-pill games-activity-pill--#{tone}"
  end

  def profile_last_active_at(profile, viewer, can_view_gaming_activity: nil, latest_visible_game_activity_at: nil)
    can_view_gaming_activity = profile.gaming_activity_visible_to?(viewer) if can_view_gaming_activity.nil?
    return unless can_view_gaming_activity

    latest_auth_activity_at = [profile.user.last_sign_in_at, profile.user.current_sign_in_at].compact.max
    latest_visible_game_activity_at ||= profile_latest_visible_game_activity_at(profile, viewer)

    [latest_auth_activity_at, latest_visible_game_activity_at].compact.max
  end

  def profile_last_active_label(profile, viewer, can_view_gaming_activity: nil, last_active_at: nil)
    can_view_gaming_activity = profile.gaming_activity_visible_to?(viewer) if can_view_gaming_activity.nil?
    return "Hidden" unless can_view_gaming_activity

    last_active_at ||= profile_last_active_at(
      profile,
      viewer,
      can_view_gaming_activity:
    )

    last_active_at ? "#{time_ago_in_words(last_active_at)} ago" : "Never"
  end

  def friends_sort_options(tab = "friends", own_profile: false)
    options = FRIENDS_SORT_OPTIONS.fetch(tab.to_s, FRIENDS_SORT_OPTIONS.fetch("friends"))
    return options if own_profile || tab.to_s != "friends"

    options.reject { |(_, value)| value.start_with?("friends_since_") }
  end

  def friends_default_sort(tab = "friends", own_profile: false)
    friends_sort_options(tab, own_profile:).first&.last
  end

  def friends_resolved_sort(tab, requested_sort = params[:sort], own_profile: false)
    options = friends_sort_options(tab, own_profile:)
    requested_sort = requested_sort.to_s
    allowed_values = options.map(&:last)

    allowed_values.include?(requested_sort) ? requested_sort : friends_default_sort(tab, own_profile:)
  end

  def friends_tab_path(profile, tab, filter_params = request.query_parameters, own_profile: false)
    next_sort = filter_params["sort"].present? ? friends_resolved_sort(tab, filter_params["sort"], own_profile:) : nil
    next_params = filter_params.slice("search_name").merge(tab:)
    next_params[:sort] = next_sort if next_sort.present? && next_sort != friends_default_sort(tab, own_profile:)

    profile_friends_path(profile, next_params)
  end

  def friends_sort_link(profile, label, current_sort, sort_keys)
    asc_key = sort_keys.fetch(:asc)
    desc_key = sort_keys.fetch(:desc)
    direction = friends_sort_direction(current_sort, asc_key, desc_key)
    next_sort = direction == "asc" ? desc_key : asc_key
    indicator = friends_sort_indicator(direction)

    link_to(
      "#{label}#{indicator}",
      profile_friends_path(profile, request.query_parameters.merge(sort: next_sort, page: nil)),
      class: "games-sort-link#{' active' if direction.present?}",
      data: { turbo_frame: "friends_list", turbo_action: "replace" }
    )
  end

  def profile_running_game_summary(profile, viewer, can_view_gaming_activity: nil)
    can_view_gaming_activity = profile.gaming_activity_visible_to?(viewer) if can_view_gaming_activity.nil?
    return unless can_view_gaming_activity

    summaries = profile_running_game_summaries(profile, viewer)
    total_count = summaries.length
    return if total_count.zero?

    first_name = summaries.first
    return "Now playing: #{first_name}" if total_count == 1

    "Now playing: #{first_name} +#{total_count - 1} more"
  end

  def profile_relation_time_label(timestamp)
    return "Unknown" unless timestamp

    "#{time_ago_in_words(timestamp)} ago"
  end

  def public_profile_name(user)
    user.profile&.name.presence || "Unknown user"
  end

  def profile_friendship_state_label(state)
    {
      friends: "Friends",
      blocked_by_you: "Blocked",
      blocked_you: "Blocked you",
      invite_sent: "Invite sent",
      invite_received: "Invite received",
      invite_declined: "Invite declined",
      you_declined: "You declined"
    }[state&.to_sym]
  end

  def profile_friendship_state_class(state)
    case state&.to_sym
    when :friends
      "profiles-info-pill profiles-info-pill-success"
    when :blocked_by_you, :blocked_you
      "profiles-info-pill profiles-info-pill-danger"
    when :invite_sent, :invite_received
      "profiles-info-pill profiles-info-pill-info"
    when :invite_declined, :you_declined
      "profiles-info-pill profiles-info-pill-muted"
    end || "profiles-info-pill"
  end

  private

  def friends_sort_direction(current_sort, asc_key, desc_key)
    return "asc" if current_sort == asc_key
    return "desc" if current_sort == desc_key

    nil
  end

  def friends_sort_indicator(direction)
    { "asc" => " \u2191", "desc" => " \u2193", nil => "" }.fetch(direction)
  end

  def profile_latest_visible_game_activity_at(profile, viewer)
    scope = profile.user.games.where.not(last_activity: nil)
    scope = scope.where(private_override: false) unless viewer&.id == profile.user_id
    scope.maximum(:last_activity)
  end

  def profile_running_game_summaries(profile, viewer)
    scope = profile.user.games.where(is_running: true)
    scope = scope.where(private_override: false) unless viewer&.id == profile.user_id
    scope.order(Arel.sql("LOWER(name) ASC")).pluck(:name)
  end
end
# rubocop:enable Metrics/ModuleLength
