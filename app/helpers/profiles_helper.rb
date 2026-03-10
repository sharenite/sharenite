# frozen_string_literal: true
# Profiles helper
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
    game_activity_states(game).map { |state| state[:label] }
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

  def profile_running_game_summary(profile, viewer)
    return unless profile.gaming_activity_visible_to?(viewer)

    summaries = profile_running_game_summaries(profile)
    total_count = summaries.length
    return if total_count.zero?

    first_name = summaries.first
    return "Now playing: #{first_name}" if total_count == 1

    "Now playing: #{first_name} +#{total_count - 1} more"
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

  def profile_running_game_summaries(profile)
    @profile_running_game_summaries ||= {}
    @profile_running_game_summaries[profile.id] ||= profile.user.games.where(is_running: true).order(Arel.sql("LOWER(name) ASC")).pluck(:name)
  end
end
