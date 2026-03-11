# frozen_string_literal: true

require "set"

module Profiles
  # Shared visibility and stats helpers for profile pages.
  # rubocop:disable Metrics/ModuleLength
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
        games_played_count: @profile.gaming_activity_visible_to?(current_user) ? visible_games_scope_for(@profile.user).where.not(last_activity: nil).count : nil,
        playlists_count: playlists_count_value,
        active_friends_count: visible_friend_user_ids.count
      }
    end

    def active_games_scope
      visible_games_scope_for(@profile.user).where(
        "is_launching = :active OR is_running = :active OR is_installing = :active OR is_uninstalling = :active",
        active: true
      ).order(Arel.sql("LOWER(name) ASC"))
    end

    def recent_games_scope
      visible_games_scope_for(@profile.user).where.not(last_activity: nil).order(last_activity: :desc)
    end

    def base_profiles_scope
      scope = visible_profiles_scope
      blocked_ids = blocked_user_ids_for(current_user)
      scope = scope.where.not(user_id: blocked_ids) if blocked_ids.any?
      scope
    end

    def games_count_value(user)
      visible_games_scope_for(user).count
    end

    def playlists_count_value
      return @profile.user.playlists.count if current_user&.id == @profile.user_id
      return @profile.user.playlists.where(private_override: false).count if @profile.playlists_visible_to?(current_user)

      0
    end

    def visible_games_scope_for(user, viewer: current_user)
      scope = user.games
      return scope if viewer&.id == user.id

      scope.where(private_override: false)
    end

    def visible_games_count_by_user_id(profiles, viewer: current_user)
      user_ids = Array(profiles).filter_map(&:user_id).uniq
      return {} if user_ids.empty?

      scope = Game.where(user_id: user_ids)
      scope = if viewer
                scope.where("games.user_id = :viewer_id OR games.private_override = FALSE", viewer_id: viewer.id)
              else
                scope.where(private_override: false)
              end

      scope.group(:user_id).count
    end

    def running_game_summary_by_user_id_for_profiles(profiles, gaming_activity_visibility_by_user_id: nil, viewer: current_user)
      profiles = Array(profiles)
      return {} if profiles.empty?

      gaming_activity_visibility_by_user_id ||= component_visibility_by_user_id(profiles, :gaming_activity_privacy, viewer:)
      visible_user_ids = visible_gaming_activity_user_ids(profiles, gaming_activity_visibility_by_user_id)
      return {} if visible_user_ids.empty?

      running_games_scope(visible_user_ids, viewer).group_by(&:user_id).transform_values do |games|
        build_running_game_summary(games)
      end
    end

    def visible_gaming_activity_user_ids(profiles, gaming_activity_visibility_by_user_id)
      profiles.filter_map { |profile| profile.user_id if gaming_activity_visibility_by_user_id[profile.user_id] }
    end

    def running_games_scope(user_ids, viewer)
      scope = Game.where(user_id: user_ids, is_running: true).order(Arel.sql("LOWER(name) ASC"))
      return scope.where(private_override: false) if viewer.blank?

      scope.where("games.user_id = :viewer_id OR games.private_override = FALSE", viewer_id: viewer.id)
    end

    def build_running_game_summary(games)
      first_name = games.first.name
      return "Now playing: #{first_name}" if games.one?

      "Now playing: #{first_name} +#{games.length - 1} more"
    end

    # Keep the keyword signature aligned with callers that pass viewer/profile table context.
    # rubocop:disable Lint/UnusedMethodArgument
    def visible_game_count_sql(viewer: current_user, profiles_table: "profiles")
      "COUNT(visible_games.id)"
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def visible_games_join_sql(viewer: current_user, profiles_table: "profiles", users_table: "users")
      visibility_sql = visible_game_library_condition_sql(viewer:, profiles_table:)
      <<~SQL.squish
        LEFT JOIN games AS visible_games
          ON visible_games.user_id = #{users_table}.id
         AND visible_games.private_override = FALSE
         AND (#{visibility_sql})
      SQL
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

      @blocked_user_ids_by_viewer_id ||= {}
      @blocked_user_ids_by_viewer_id[viewer.id] ||= Friend.where(status: :blocked)
                                                          .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: viewer.id)
                                                          .pluck(:inviter_id, :invitee_id)
                                                          .flatten
                                                          .uniq
                                                          .excluding(viewer.id)
    end

    def accepted_friend_user_ids_list_for(user_id)
      @accepted_friend_user_ids_list_by_user_id ||= {}
      @accepted_friend_user_ids_list_by_user_id[user_id] ||= Friend.where(status: :accepted)
                                                                 .where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
                                                                 .pluck(:inviter_id, :invitee_id)
                                                                 .flatten
                                                                 .uniq
                                                                 .excluding(user_id)
    end

    def component_visibility_by_user_id(profiles, column, viewer: current_user, allow_blocked: false)
      visibility_context = {
        accepted_friend_user_ids: viewer.present? ? accepted_friend_user_ids_list_for(viewer.id).to_set : Set.new,
        blocked_user_ids: viewer.present? ? blocked_user_ids_for(viewer).to_set : Set.new,
        allow_blocked:
      }

      Array(profiles).each_with_object({}) do |profile, visibility_by_user_id|
        visibility_by_user_id[profile.user_id] = component_visible_to_viewer?(
          profile,
          column,
          viewer:,
          visibility_context:
        )
      end
    end

    def component_visible_to_viewer?(profile, column, viewer:, visibility_context:)
      accepted_friend_user_ids = visibility_context.fetch(:accepted_friend_user_ids)
      return false if !visibility_context.fetch(:allow_blocked) && visibility_context.fetch(:blocked_user_ids).include?(profile.user_id)
      return false unless privacy_setting_visible_to_viewer?(profile.privacy, profile.user_id, viewer, accepted_friend_user_ids)

      privacy_setting_visible_to_viewer?(
        profile.public_send(column),
        profile.user_id,
        viewer,
        accepted_friend_user_ids
      )
    end

    def privacy_setting_visible_to_viewer?(setting, profile_user_id, viewer, accepted_friend_user_ids)
      return true if viewer&.id == profile_user_id

      case setting
      when "public"
        true
      when "members"
        viewer.present?
      when "friends"
        accepted_friend_user_ids.include?(profile_user_id)
      else
        false
      end
    end

    def visible_game_library_condition_sql(viewer: current_user, profiles_table: "profiles")
      profile_user_column = "#{profiles_table}.user_id"
      privacy_column = "#{profiles_table}.game_library_privacy"

      return "#{privacy_column} = 'public'" unless viewer

      friend_user_ids_sql = accepted_friend_user_ids_for(viewer.id).to_sql
      quoted_viewer_id = ActiveRecord::Base.connection.quote(viewer.id)

      <<~SQL.squish
        #{profile_user_column} = #{quoted_viewer_id}
        OR #{privacy_column} IN ('public', 'members')
        OR (#{privacy_column} = 'friends' AND #{profile_user_column} IN (#{friend_user_ids_sql}))
      SQL
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
