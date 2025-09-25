class RegChancenRegistrationsController < RegistrationsController
  def welcome
  end

  def create
    if @invitation
      @user.family = @invitation.family
      @user.role = @invitation.role
      @user.email = @invitation.email
    else
      family = Family.new
      @user.family = family
      @user.role = :admin
    end

    if @user.save
      @invitation&.update!(accepted_at: Time.current)
      @session = create_session_for(@user)
      redirect_to chancen_onboarding_path, notice: t("registrations.create.success")
    else
      render :new, status: :unprocessable_entity, alert: t("registrations.create.failure")
    end
  end

  private
    def claim_invite_code
      unless InviteCode.claim!(params.dig(:user, :invite_code))
        redirect_to new_reg_chancen_path, alert: t("registrations.create.invalid_invite_code")
      end
    end

    def set_user
      super
      @user.pei = "kenya"
      @user.bank = "choice"
    end
end
