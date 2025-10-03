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
      return if Partners::OnboardingSteps.include?(@partner, step)

      head :not_found
    end

    def load_invitation
      @invitation = Current.family.invitations.accepted.find_by(email: Current.user.email)
    end
end
