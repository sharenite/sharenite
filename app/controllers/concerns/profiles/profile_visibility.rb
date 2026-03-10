# frozen_string_literal: true

module Profiles
  # Shared visibility and stats helpers for profile pages.
  module ProfileVisibility
    private

    def assign_visibility_flags
      @can_view_games = @profile.game_library_visible_to?(current_user)
      @can_view_gaming_activity = @profile.gaming_activity_visible_to?(current_user)
      @can_view_playlists = @profile.playlists_visible_to?(current_user)
      @can_view_friends = @profile.friends_list_visible_to?(current_user)
    end

    def assign_activity_sections
      return assign_hidden_activity_sections unless @can_view_gaming_activity

      @recent_games = recent_games_scope.limit(5).to_a
      @active_games = active_games_scope.limit(8).to_a
    end

    def assign_hidden_activity_sections
      @recent_games = []
      @active_games = []
    end

    def build_profile_stats
      profile_user_id = @profile.user_id
      visible_friend_user_ids = apply_profile_visibility_scope(
        Profile.where(user_id: accepted_friend_user_ids_for(profile_user_id))
      )

      {
        games_count: games_count_value(@profile.user),
        games_played_count: @profile.user.games.where.not(last_activity: nil).count,
        playlists_count: playlists_count_value(profile_user_id),
        active_friends_count: visible_friend_user_ids.count
      }
    end

    def active_games_scope
      @profile.user.games.where(
        "is_launching = :active OR is_running = :active OR is_installing = :active OR is_uninstalling = :active",
        active: true
      ).order(Arel.sql("LOWER(name) ASC"))
    end

    def recent_games_scope
      @profile.user.games.where.not(last_activity: nil).order(last_activity: :desc)
    end

    def base_profiles_scope
      scope = visible_profiles_scope
      blocked_ids = blocked_user_ids_for(current_user)
      scope = scope.where.not(user_id: blocked_ids) if blocked_ids.any?
      return scope.select("profiles.*, COALESCE(users.games_count, 0) AS games_count") if User.games_count_available?

      scope.left_joins(user: :games)
           .select("profiles.*, COUNT(games.id) AS games_count")
           .group("profiles.id")
    end

    def games_count_value(user)
      return user.games_count.to_i if User.games_count_available?

      user.games.count
    end

    def playlists_count_value(user_id)
      scope = Playlist.where(user_id:)
      return scope.count if profile_own?

      scope.where(public: true).count
    end

    def accepted_friend_user_ids_for(user_id)
      quoted_user_id = ActiveRecord::Base.connection.quote(user_id)
      sql = "DISTINCT CASE WHEN inviter_id = #{quoted_user_id} THEN invitee_id ELSE inviter_id END"
      Friend.where(status: :accepted)
            .where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
            .select(Arel.sql(sql))
    end

    def visible_profiles_scope
      apply_profile_visibility_scope(Profile.joins(:user))
    end

    def apply_profile_visibility_scope(scope, viewer: current_user)
      return scope.where(privacy: :public) unless viewer

      friend_user_ids = accepted_friend_user_ids_for(viewer.id)
      visible_scope = scope.where(
        "profiles.user_id = :viewer_id OR profiles.privacy IN (:broad_privacies) " \
        "OR (profiles.privacy = 'friends' AND profiles.user_id IN (#{friend_user_ids.to_sql}))",
        viewer_id: viewer.id,
        broad_privacies: %w[public members]
      )

      blocked_ids = blocked_user_ids_for(viewer)
      return visible_scope if blocked_ids.empty?

      visible_scope.where.not(user_id: blocked_ids)
    end

    def blocked_user_ids_for(viewer)
      return [] unless viewer

      Friend.where(status: :blocked)
           .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: viewer.id)
           .pluck(:inviter_id, :invitee_id)
           .flatten
           .uniq
           .excluding(viewer.id)
    end
  end
end
