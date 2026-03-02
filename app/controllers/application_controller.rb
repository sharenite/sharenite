# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.credentials.http_basic.user, password: Rails.application.credentials.http_basic.password, if: -> { Rails.env.staging? }

  before_action :redirect_www_to_canonical_host
  before_action :authenticate_user!
  helper_method :captcha_required?, :current_profile, :pending_friend_invites_count

  # Devise overrides
  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def current_profile
    return unless user_signed_in?

    @current_profile ||= current_user.profile
  end

  def pending_friend_invites_count
    return 0 unless user_signed_in?

    @pending_friend_invites_count ||= Friend.where(invitee_id: current_user.id, status: :invited).count
  end

  def captcha_required?
    default = Rails.env.production? || Rails.env.staging?
    enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RECAPTCHA_ENABLED", default))
    return false unless enabled
    return true if recaptcha_configured?

    Rails.logger.warn("[captcha] RECAPTCHA is enabled but missing site/secret keys. Captcha protection disabled.")
    false
  end

  def recaptcha_configured?
    ENV["RECAPTCHA_SITE_KEY"].present? && ENV["RECAPTCHA_SECRET_KEY"].present?
  end

  def invalid_url!
    raise ActiveRecord::RecordNotFound, "Not Found"
  end

  def redirect_www_to_canonical_host
    return unless production_canonical_redirect?

    canonical_host = canonical_request_host
    return if canonical_host.blank?
    return unless should_redirect_to_canonical_host?(canonical_host)

    redirect_to "#{request.protocol}#{canonical_host}#{request.fullpath}", status: :permanent_redirect, allow_other_host: true
  rescue KeyError
    nil
  end

  def production_canonical_redirect?
    Rails.env.production? && request.path != "/up"
  end

  def canonical_request_host
    ENV.fetch("HOST").sub(%r{\Ahttps?://}, "").split("/").first
  end

  def should_redirect_to_canonical_host?(canonical_host)
    return false if request.host == canonical_host

    redirect_source_for(canonical_host) == request.host
  end

  def redirect_source_for(canonical_host)
    if canonical_host.start_with?("www.")
      canonical_host.delete_prefix("www.")
    else
      "www.#{canonical_host}"
    end
  end
end
