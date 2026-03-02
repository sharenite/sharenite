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
      @profile_stats = build_profile_stats
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

      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)

      scope = apply_games_count_filter(scope, games_from:, games_to:)

      scope.order("profiles.name ASC")
    end

    def parse_games_count_param(key)
      value = params[key].to_s.strip
      return if value.blank?

      parsed = Integer(value, 10)
      parsed.negative? ? nil : parsed
    rescue ArgumentError
      nil
    end

    def friendship_states_for_user_ids(user_ids)
      return {} unless user_signed_in?

      FriendshipStateResolver.states_for_users(current_user_id: current_user.id, user_ids:)
    end

    def check_profile
      redirect_to_profiles_with_notice if @profile.nil? || 
        (!profile_own? && 
        !profile_public? && 
        !profile_friendly? && 
        !profile_friend?)
    end

    def profile_friendly?
      @profile.privacy_friendly?
    end

    def profile_params
      params.require(:profile).permit(:name, :privacy, :game_library_privacy, :vanity_url)
    end

    def set_profile
      @profile = Profile.includes(:user).friendly.find(params[:id])
    end

    def build_profile_stats
      profile_user_id = @profile.user_id
      is_own_profile = user_signed_in? && @current_user_id == profile_user_id

      {
        games_count: games_count_value(@profile.user),
        playlists_count: Playlist.where(user_id: profile_user_id).count,
        active_friends_count: Friend.where(status: :accepted)
                                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: profile_user_id)
                                    .count,
        pending_received_count: is_own_profile ? Friend.where(invitee_id: profile_user_id, status: :invited).count : 0
      }
    end

    def base_profiles_scope
      scope = Profile.privacy_public.joins(:user)
      return scope.select("profiles.*, COALESCE(users.games_count, 0) AS games_count") if User.games_count_available?

      scope.left_joins(user: :games)
           .select("profiles.*, COUNT(games.id) AS games_count")
           .group("profiles.id")
    end

    def apply_games_count_filter(scope, games_from:, games_to:)
      return scope if games_from.nil? && games_to.nil?

      comparator = User.games_count_available? ? "COALESCE(users.games_count, 0)" : "COUNT(games.id)"
      apply_games_count_bounds(scope, comparator:, games_from:, games_to:)
    end

    def apply_games_count_bounds(scope, comparator:, games_from:, games_to:)
      if User.games_count_available?
        scope = scope.where("#{comparator} >= ?", games_from) unless games_from.nil?
        return scope.where("#{comparator} <= ?", games_to) unless games_to.nil?

        return scope
      end

      scope = scope.having("#{comparator} >= ?", games_from) unless games_from.nil?
      return scope.having("#{comparator} <= ?", games_to) unless games_to.nil?

      scope
    end

    def games_count_value(user)
      return user.games_count.to_i if User.games_count_available?

      user.games.count
    end
  end
end
