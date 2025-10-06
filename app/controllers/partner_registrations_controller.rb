class PartnerRegistrationsController < RegistrationsController
  prepend_before_action :set_partner

  def new
    super
    apply_partner_defaults(@user)
  end

  def welcome; end

  def privacy; end

  def consent; end

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

    apply_partner_defaults(@user)

    if @user.save
      @invitation&.update!(accepted_at: Time.current)
      @session = create_session_for(@user)
      redirect_to partner_onboarding_path(partner_key: @partner.key), notice: t("registrations.create.success")
    else
      render :new, status: :unprocessable_entity, alert: t("registrations.create.failure")
    end
  end

  private
    def claim_invite_code
      unless InviteCode.claim!(params.dig(:user, :invite_code))
        redirect_to new_partner_registration_path(partner_key: @partner&.key || partner_key), alert: t("registrations.create.invalid_invite_code")
      end
    end

    def set_partner
      @partner = Partners.find(partner_key) || Partners.default
    end

    def partner_key
      params[:partner_key] || params.dig(:user, :partner_metadata, :key) || Partners.default&.key
    end

    def set_user
      @user = User.new user_params.except(:invite_code, :invitation, :partner_metadata)
      apply_partner_defaults(@user)
    end

    def apply_partner_defaults(user)
      return unless user

      metadata = default_partner_metadata
      metadata.merge!(partner_metadata_params) if params[:user].present?
      user.partner_metadata = metadata if metadata.present?
    end

    def default_partner_metadata
      (@partner&.default_metadata || {}).dup
    end

    def partner_metadata_params
      return {} unless params[:user].is_a?(ActionController::Parameters)

      metadata = params.require(:user).permit(partner_metadata: {})[:partner_metadata]
      return {} if metadata.blank?

      metadata = metadata.to_unsafe_h if metadata.respond_to?(:to_unsafe_h)
      metadata.to_h.deep_stringify_keys
    end

    def user_params(specific_param = nil)
      permitted = params.require(:user).permit(:name, :email, :password, :password_confirmation, :invite_code, :invitation, partner_metadata: {})
      specific_param ? permitted[specific_param] : permitted
    end
end
