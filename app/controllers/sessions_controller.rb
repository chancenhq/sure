class SessionsController < ApplicationController
  before_action :set_session, only: :destroy
  skip_authentication only: %i[new create]

  layout "auth"

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      if user.otp_required?
        session[:mfa_user_id] = user.id
        redirect_to verify_mfa_path
      else
        @session = create_session_for(user)
        redirect_to root_path
      end
    else
      flash.now[:alert] = t(".invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def openid_connect
    auth = auth_from_request

    if auth.blank?
      redirect_with_oidc_alert(:failure)
      return
    end

    info = auth[:info] || {}

    unless ActiveModel::Type::Boolean.new.cast(info[:email_verified])
      redirect_with_oidc_alert(:email_not_verified)
      return
    end

    uid = auth[:uid].to_s
    email = info[:email].to_s.strip.downcase

    if uid.blank? || email.blank?
      redirect_with_oidc_alert(:failure)
      return
    end

    if (user = User.find_by(oidc_subject: uid))
      complete_oidc_sign_in(user)
      return
    end

    if User.exists?(email: email)
      redirect_with_oidc_alert(:email_taken)
      return
    end

    user = create_user_from_oidc!(email: email, uid: uid)
    complete_oidc_sign_in(user)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => error
    Rails.logger.error("OIDC sign-in failed: #{error.class}: #{error.message}")
    redirect_with_oidc_alert(:failure)
  end

  def destroy
    @session.destroy
    redirect_to new_session_path, notice: t(".logout_successful")
  end

  private
    def auth_from_request
      raw_auth = request.env["omniauth.auth"]
      return {} if raw_auth.blank?

      auth_hash = raw_auth.respond_to?(:to_h) ? raw_auth.to_h : raw_auth
      auth_hash.deep_symbolize_keys
    end

    def create_user_from_oidc!(email:, uid:)
      User.transaction do
        family = Family.create!
        password = SecureRandom.base58(24)

        family.users.create!(
          email: email,
          oidc_subject: uid,
          role: :admin,
          password: password
        )
      end
    end

    def complete_oidc_sign_in(user)
      if user.otp_required?
        session[:mfa_user_id] = user.id
        redirect_to verify_mfa_path
      else
        @session = create_session_for(user)
        redirect_to user.needs_onboarding? ? onboarding_path : root_path
      end
    end

    def redirect_with_oidc_alert(key)
      redirect_to new_session_path, alert: t(".#{key}")
    end

    def set_session
      @session = Current.user.sessions.find(params[:id])
    end
end
