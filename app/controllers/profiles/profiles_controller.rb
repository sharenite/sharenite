# frozen_string_literal: true
module Profiles
  # Profiles controller
  class ProfilesController < BaseController
    before_action :check_general_access_profile, only: %i[show]

    def index
      @profiles = profiles_scope.page(params[:page])
      @friendship_states_by_user_id = friendship_states_for_user_ids(@profiles.map(&:user_id))
      @current_user_id = current_user&.id
      @current_profile_slug = current_user&.profile&.slug
    end

    def show
      @friendship_state = friendship_states_for_user_ids([@profile.user_id])[@profile.user_id]
      @current_user_id = current_user&.id
      @current_profile = current_user&.profile
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

    # rubocop:disable Metrics/AbcSize
    def profiles_scope
      scope = Profile.privacy_public
                     .joins(:user)
                     .joins("LEFT JOIN (#{games_count_subquery.to_sql}) games_count_stats ON games_count_stats.user_id = profiles.user_id")
                     .select("profiles.*, COALESCE(games_count_stats.games_count, 0) AS games_count")

      name_query = params[:search_name].to_s.strip
      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?

      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)

      scope = scope.where("COALESCE(games_count_stats.games_count, 0) >= ?", games_from) unless games_from.nil?
      scope = scope.where("COALESCE(games_count_stats.games_count, 0) <= ?", games_to) unless games_to.nil?

      scope.order("profiles.name ASC")
    end
    # rubocop:enable Metrics/AbcSize

    def games_count_subquery
      Game.select("games.user_id, COUNT(games.id) AS games_count").group("games.user_id")
    end

    def parse_games_count_param(key)
      value = params[key].to_s.strip
      return if value.blank?

      parsed = Integer(value, 10)
      parsed.negative? ? nil : parsed
    rescue ArgumentError
      nil
    end

    # rubocop:disable Metrics/AbcSize
    def friendship_states_for_user_ids(user_ids)
      return {} unless user_signed_in?

      ids = user_ids.uniq - [current_user.id]
      return {} if ids.empty?

      relations_by_other_user_id = Hash.new { |hash, key| hash[key] = [] }
      FriendshipStateResolver.relations_scope(current_user_id: current_user.id, user_ids: ids).find_each do |relation|
        other_user_id = relation.inviter_id == current_user.id ? relation.invitee_id : relation.inviter_id
        relations_by_other_user_id[other_user_id] << relation
      end

      relations_by_other_user_id.transform_values do |relations|
        FriendshipStateResolver.state_from_relations(relations:, current_user_id: current_user.id)
      end
    end
    # rubocop:enable Metrics/AbcSize

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
      params.require(:profile).permit(:name, :privacy, :vanity_url)
    end

    def set_profile
      @profile = Profile.includes(:user).friendly.find(params[:id])
    end

    def build_profile_stats
      profile_user_id = @profile.user_id
      is_own_profile = user_signed_in? && @current_user_id == profile_user_id

      {
        games_count: Game.where(user_id: profile_user_id).count,
        playlists_count: Playlist.where(user_id: profile_user_id).count,
        active_friends_count: Friend.where(status: :accepted)
                                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: profile_user_id)
                                    .count,
        pending_received_count: is_own_profile ? Friend.where(invitee_id: profile_user_id, status: :invited).count : 0
      }
    end
  end
end
