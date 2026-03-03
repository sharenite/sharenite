# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_user = ENV["HTTP_BASIC_USER"].presence
  http_basic_password = ENV["HTTP_BASIC_PASSWORD"].presence
  if Rails.env.staging? && (http_basic_user.blank? || http_basic_password.blank?)
    begin
      http_basic_user ||= Rails.application.credentials.dig(:http_basic, :user).presence
      http_basic_password ||= Rails.application.credentials.dig(:http_basic, :password).presence
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      # Keep basic auth disabled when credentials cannot be decrypted.
    end
  end
  if Rails.env.staging? && http_basic_user.present? && http_basic_password.present?
    http_basic_authenticate_with name: http_basic_user, password: http_basic_password
  end
  class_attribute :missing_recaptcha_keys_warning_logged, instance_writer: false, default: false

  before_action :redirect_www_to_canonical_host
  before_action :authenticate_user!
  before_action :sign_out_if_account_deleting
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

  def sign_out_if_account_deleting
    return unless user_signed_in?
    return unless current_user.deleting?

    sign_out(current_user)
    redirect_to root_path, alert: I18n.t("devise.failure.deleting")
  end

  def captcha_required?
    default = Rails.env.production? || Rails.env.staging?
    enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RECAPTCHA_ENABLED", default))
    return false unless enabled
    return true if recaptcha_configured?

    log_missing_recaptcha_keys_once
    false
  end

  def recaptcha_configured?
    ENV["RECAPTCHA_SITE_KEY"].present? && ENV["RECAPTCHA_SECRET_KEY"].present?
  end

  def log_missing_recaptcha_keys_once
    return if self.class.missing_recaptcha_keys_warning_logged

    Rails.logger.warn("[captcha] RECAPTCHA is enabled but missing site/secret keys. Captcha protection disabled.")
    self.class.missing_recaptcha_keys_warning_logged = true
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
