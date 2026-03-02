# frozen_string_literal: true

# Static pages controller
class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:landing_page]

  # rubocop:disable Metrics/AbcSize
  def dashboard
    @profile = current_user.profile
    games_scope = current_user.games

    @dashboard_stats = {
      games_total: games_scope.count,
      games_favorites: games_scope.where(favorite: true).count,
      games_installed: games_scope.where(is_installed: true).count,
      games_played: games_scope.where.not(last_activity: nil).count,
      playlists_total: current_user.playlists.count,
      friends_total: current_user.friends.count,
      invites_received: current_user.pending_inviters.count,
      invites_sent: current_user.pending_invitees.count
    }

    @recent_games = games_scope.where.not(last_activity: nil).order(last_activity: :desc).limit(5)
  end
  # rubocop:enable Metrics/AbcSize

  def landing_page
  end
end
