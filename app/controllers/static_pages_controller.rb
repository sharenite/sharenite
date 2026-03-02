# frozen_string_literal: true

# Static pages controller
class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:landing_page]

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def dashboard
    @profile = current_user.profile
    user_id = current_user.id
    games_scope = current_user.games
    games_total, games_favorites, games_installed, games_played = game_counts(games_scope)
    friends_total, invites_received, invites_sent = friend_counts(user_id)

    @dashboard_stats = {
      games_total:,
      games_favorites:,
      games_installed:,
      games_played:,
      playlists_total: current_user.playlists.count,
      friends_total:,
      invites_received:,
      invites_sent:
    }

    @recent_games = games_scope.where.not(last_activity: nil).order(last_activity: :desc).limit(5).to_a
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def landing_page
  end

  private

  def game_counts(games_scope)
    games_scope.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("SUM(CASE WHEN favorite THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN is_installed THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN last_activity IS NOT NULL THEN 1 ELSE 0 END)")
    ).map(&:to_i)
  end

  def friend_counts(user_id)
    accepted_count = Friend.where(status: :accepted)
                           .where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
                           .count

    [
      accepted_count,
      Friend.where(invitee_id: user_id, status: :invited).count,
      Friend.where(inviter_id: user_id, status: :invited).count
    ]
  end
end
