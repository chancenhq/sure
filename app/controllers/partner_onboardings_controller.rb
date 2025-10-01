class PartnerOnboardingsController < ApplicationController
  layout "wizard"

  before_action :set_user
  before_action :ensure_partner
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

    def load_invitation
      @invitation = Current.family.invitations.accepted.find_by(email: Current.user.email)
    end
end
