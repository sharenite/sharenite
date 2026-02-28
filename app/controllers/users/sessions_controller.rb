# frozen_string_literal: true

module Users
  # Custom Devise sessions flow with conditional reCAPTCHA protection.
  class SessionsController < Devise::SessionsController
    before_action :configure_sign_in_params
    prepend_before_action :check_captcha

    protected

    def configure_sign_in_params
      return unless action_name == "create"

      devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    end

    private

    def check_captcha
      return unless action_name == "create"
      return unless captcha_required?
      return if verify_recaptcha # verify_recaptcha(action: 'login') for v3

      self.resource = resource_class.new sign_in_params

      respond_with_navigational(resource) do
        flash.discard(:recaptcha_error) # We need to discard flash to avoid showing it on the next page reload
        render :new
      end
    end
  end
end
