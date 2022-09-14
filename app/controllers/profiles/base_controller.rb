# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles base controller
  class BaseController < InheritedResources::Base
    before_action :check_current_user_profile, except: %i[index show]
    before_action :check_general_access_profile, only: %i[index show]
    skip_before_action :authenticate_user!, only: %i[index show]

    def index
    end

    def show
    end

    def edit
    end

    def update
    end

    def destroy
    end

    private

    def set_profile
      @profile = Profile.friendly.find_by(id: params[:profile_id])
    end

    def check_current_user_profile
      set_profile
      redirect_to_profiles_with_notice if @profile != current_user.profile
    end

    def check_general_access_profile
      set_profile
      check_profile
    end

    def check_profile
      redirect_to_profiles_with_notice if @profile.nil? || (@profile != current_user&.profile && !@profile.privacy_public?)
      #   TODO: additional checks for public and friendly
    end

    def redirect_to_profiles_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Profile not found."
      # rubocop:enable all
      redirect_to profiles_path
    end
  end
end
