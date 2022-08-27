# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  # Devise overrides

  def after_sign_out_path_for(_resource_or_scope)
    logger.debug '------------------'
    logger.debug 'we here?'
    root_path
  end
end
