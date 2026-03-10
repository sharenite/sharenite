# frozen_string_literal: true

# Static pages controller
class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:landing_page]

  def dashboard
    redirect_to profile_path(current_profile)
  end

  def landing_page
  end

end
