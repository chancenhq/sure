class RegChancenRegistrationsController < RegistrationsController
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
    def set_user
      super
      @user.pei = "kenya"
      @user.bank = "choice"
    end
end
