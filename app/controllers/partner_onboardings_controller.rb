class PartnerOnboardingsController < ApplicationController
  layout "wizard"

  ACTION_TO_STEP = {
    "show" => :setup,
    "preferences" => :preferences,
    "goals" => :goals,
    "trial" => :trial
  }.freeze

  before_action :set_user
  before_action :ensure_partner
  before_action :ensure_step_available
  before_action :prepare_navigation
  before_action :load_invitation

  def show; end

  def preferences; end

  def goals; end

  def trial; end

  private
    def set_user
      @user = Current.user
    end

    def ensure_partner
      key = params[:partner_key] || @user.partner_key
      @partner = Partners.find(key) || Partners.default
    end

    def ensure_step_available
      step = ACTION_TO_STEP[action_name]
      return unless step

      Partners::OnboardingSteps.auto_complete_missing_steps!(partner: @partner, user: @user)

      return if Partners::OnboardingSteps.include?(@partner, step)

      next_path = Partners::OnboardingSteps.first_step_path(
        partner: @partner,
        view_context: self,
        route_params: partner_route_params
      )

      if next_path.present?
        redirect_to next_path and return
      end

      complete_partner_onboarding!
      redirect_to root_path
    end

    def load_invitation
      @invitation = Current.family.invitations.accepted.find_by(email: Current.user.email)
    end

    def prepare_navigation
      step = ACTION_TO_STEP[action_name]
      return unless step
      return unless Partners::OnboardingSteps.include?(@partner, step)

      @previous_step_path = Partners::OnboardingSteps.previous_step_path(
        partner: @partner,
        current_step: step,
        view_context: self,
        route_params: partner_route_params
      )

      @next_step_path = Partners::OnboardingSteps.next_step_path(
        partner: @partner,
        current_step: step,
        view_context: self,
        route_params: partner_route_params
      )

      next_step_key = Partners::OnboardingSteps.next_step_key(@partner, step)
      @redirect_after_submit = next_redirect_target_for(next_step_key)
    end

    def partner_route_params
      @partner_route_params ||= { partner_key: @partner.key }
    end

    def next_redirect_target_for(step_key)
      return "home" if step_key.blank?

      case step_key.to_sym
      when :setup
        "partner_onboarding_preferences"
      when :preferences
        "partner_onboarding_goals"
      when :goals
        return "home" if self_hosted?

        "partner_onboarding_trial"
      when :trial
        "home"
      else
        "home"
      end
    end

    def complete_partner_onboarding!
      @user.update!(onboarded_at: Time.current) unless @user.onboarded?
      @user.update!(set_onboarding_goals_at: Time.current) if @user.set_onboarding_goals_at.blank?
    end
end
