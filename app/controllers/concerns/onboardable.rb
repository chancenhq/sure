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
        if partner_user?
          redirect_to partner_onboarding_entry_path
        else
          redirect_to onboarding_path
        end
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

    def partner_onboarding_entry_path
      partner_key = Current.user&.partner_key
      return partner_onboarding_path(partner_route_params) if partner_key.blank?

      partner = Partners.find(partner_key)
      Partners::OnboardingSteps.auto_complete_missing_steps!(partner: partner, user: Current.user)

      first_step_path = Partners::OnboardingSteps.first_step_path(
        partner: partner,
        view_context: self,
        route_params: partner_route_params
      )

      return partner_onboarding_path(partner_route_params) if first_step_path.blank?

      first_step_path
    end
end
