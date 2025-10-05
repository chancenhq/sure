module Onboardable
  extend ActiveSupport::Concern

  included do
    before_action :require_onboarding_and_upgrade
  end

  private
    # First, we require onboarding, then once that's complete, we require an upgrade for non-subscribed users.
    def require_onboarding_and_upgrade
      return unless Current.user
      return unless redirectable_path?(request.path)

      if Current.user.needs_onboarding?
        redirect_to partner_user? ? partner_onboarding_path(partner_route_params) : onboarding_path
      elsif Current.family.needs_subscription?
        if partner_user?
          return unless partner_onboarding_step_enabled?(:trial)

          redirect_to trial_partner_onboarding_path(partner_route_params)
        else
          redirect_to trial_onboarding_path
        end
      elsif Current.family.upgrade_required?
        redirect_to upgrade_subscription_path
      end
    end

    def redirectable_path?(path)
      return false if path.starts_with?("/settings")
      return false if path.starts_with?("/subscription")
      return false if path.starts_with?("/onboarding")
      return false if path.starts_with?("/partners/")
      return false if path.starts_with?("/users")
      return false if path.starts_with?("/api")  # Exclude API endpoints from onboarding redirects

      [
        new_registration_path,
        new_session_path,
        new_password_reset_path,
        new_email_confirmation_path
      ].exclude?(path)
    end

    def partner_user?
      Current.user&.partner_key.present?
    end

    def partner_route_params
      { partner_key: Current.user.partner_key }
    end

    def partner_onboarding_step_enabled?(step)
      partner_key = Current.user&.partner_key
      return false if partner_key.blank?

      partner = Partners.find(partner_key)
      Partners::OnboardingSteps.include?(partner, step)
    end
end
