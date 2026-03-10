# frozen_string_literal: true
module Profiles
  # Profiles controller
  class ProfilesController < BaseController
    include ProfileVisibility

    before_action :check_general_access_profile, only: %i[show]

    def index
      @profiles = profiles_scope.page(params[:page])
      @friendship_states_by_user_id = friendship_states_for_user_ids(@profiles.map(&:user_id))
      @game_library_visibility_by_user_id = component_visibility_by_user_id(@profiles, :game_library_privacy)
      @current_user_id = current_user&.id
      @current_profile = current_profile
    end

    def show
      @friendship_state = friendship_states_for_user_ids([@profile.user_id])[@profile.user_id]
      @current_user_id = current_user&.id
      @current_profile = current_profile
      assign_visibility_flags
      @profile_stats = build_profile_stats
      assign_activity_sections
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
  end
end
