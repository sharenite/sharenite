# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles base controller
  class BaseController < InheritedResources::Base
    before_action :check_current_user_profile, only: %i[new create edit update destroy]
    before_action :check_general_access_profile, only: %i[index show]
    skip_before_action :authenticate_user!, only: %i[index show]

    def index
    end

    def show
    end

    def new
    end
    def edit
    end
    def create
    end



    def update
    end

    def destroy
    end

    private

    def set_profile
      @profile = Profile.friendly.find(params[:profile_id])
    end

    def check_current_user_profile
      set_profile
      redirect_to_profiles_with_notice if @profile != current_user.profile
    rescue ActiveRecord::RecordNotFound
      redirect_to_profiles_with_notice
    end

    def check_general_access_profile
      set_profile
      check_profile
    rescue ActiveRecord::RecordNotFound
      redirect_to_profiles_with_notice
    end

    def check_friendly_access_profile
      set_profile
      check_friendly_profile
    rescue ActiveRecord::RecordNotFound
      redirect_to_profiles_with_notice
    end

    def check_profile
      redirect_to_profiles_with_notice if @profile.nil? || 
        (!profile_own? && 
        !profile_public? && 
        !profile_friend?)
    end

    def check_friendly_profile
      redirect_to_profiles_with_notice if @profile.nil? || 
        (!profile_public? && 
        !profile_friendly? && 
        !profile_friend?)
    end

    def profile_friendly?
      @profile.privacy_friendly?
    end

    def profile_own?
      @profile == current_user&.profile
    end

    def profile_public?
      @profile.privacy_public?
    end

    def profile_friend?
      current_user&.friends&.include?(@profile.user) && !@profile.privacy_private?
    end

    def redirect_to_profiles_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Profile not found or set to private."
      # rubocop:enable all
      redirect_to profiles_path
    end
  end
end
