# frozen_string_literal: true
module Profiles
  # Profiles controller
  class ProfilesController < BaseController
    before_action :check_general_access_profile, only: %i[show]

    def index
      @profiles = profiles_scope.page(params[:page])
      @friendship_states_by_user_id = friendship_states_for_user_ids(@profiles.map(&:user_id))
      @current_user_id = current_user&.id
      @current_profile_slug = current_profile&.slug
    end

    def show
      @friendship_state = friendship_states_for_user_ids([@profile.user_id])[@profile.user_id]
      @current_user_id = current_user&.id
      @current_profile = current_profile
      @can_view_games = @profile.game_library_visible_to?(current_user)
      @can_view_gaming_activity = @profile.gaming_activity_visible_to?(current_user)
      @can_view_playlists = @profile.playlists_visible_to?(current_user)
      @can_view_friends = @profile.friends_list_visible_to?(current_user)
      @profile_stats = build_profile_stats
      @recent_games = @can_view_gaming_activity ? recent_games_scope.limit(5).to_a : []
      @active_games = @can_view_gaming_activity ? active_games_scope.limit(8).to_a : []
    end

    def update
      respond_to do |format|
        if @profile.update(profile_params)
          format.turbo_stream { redirect_to profile_path(@profile) }
        else
          format.turbo_stream { render turbo_stream: turbo_stream.replace("profile_errors", partial: "profile_errors") }
        end
      end
    end

    private

    def profiles_scope
      scope = base_profiles_scope

      name_query = params[:search_name].to_s.strip
      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?

      scope.order("profiles.name ASC")
    end

    def friendship_states_for_user_ids(user_ids)
      return {} unless user_signed_in?

      FriendshipStateResolver.states_for_users(current_user_id: current_user.id, user_ids:)
    end

    def profile_params
      params.require(:profile).permit(:name, :privacy, :game_library_privacy, :gaming_activity_privacy, :playlists_privacy, :friends_privacy, :vanity_url)
    end

    def set_profile
      @profile = Profile.includes(:user).friendly.find(params[:id])
    end

    def build_profile_stats
      profile_user_id = @profile.user_id
      visible_friend_user_ids = Profile.where.not(privacy: :private)
                                       .where(user_id: accepted_friend_user_ids_scope(profile_user_id))

      {
        games_count: games_count_value(@profile.user),
        games_played_count: @profile.user.games.where.not(last_activity: nil).count,
        playlists_count: Playlist.where(user_id: profile_user_id).count,
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
      scope = Profile.joins(:user)
      scope = if current_user
                scope.where.not(privacy: :private)
              else
                scope.where(privacy: :public)
              end
      if current_user
        blocked_user_ids = Friend.where(status: :blocked)
                                 .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: current_user.id)
                                 .pluck(:inviter_id, :invitee_id)
                                 .flatten
                                 .uniq - [current_user.id]
        scope = scope.where.not(user_id: blocked_user_ids) if blocked_user_ids.any?
      end
      return scope.select("profiles.*, COALESCE(users.games_count, 0) AS games_count") if User.games_count_available?

      scope.left_joins(user: :games)
           .select("profiles.*, COUNT(games.id) AS games_count")
           .group("profiles.id")
    end

    def games_count_value(user)
      return user.games_count.to_i if User.games_count_available?

      user.games.count
    end

    def accepted_friend_user_ids_scope(user_id)
      quoted_user_id = ActiveRecord::Base.connection.quote(user_id)
      sql = "DISTINCT CASE WHEN inviter_id = #{quoted_user_id} THEN invitee_id ELSE inviter_id END"
      Friend.where(status: :accepted)
            .where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
            .select(Arel.sql(sql))
    end
  end
end
