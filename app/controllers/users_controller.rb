class UsersController < ApplicationController
  before_action :set_user
  before_action :ensure_admin, only: %i[reset reset_with_sample_data]

  def update
    @user = Current.user

    if email_changed?
      if @user.initiate_email_change(user_params[:email])
        if Rails.application.config.app_mode.self_hosted? && !Setting.require_email_confirmation
          handle_redirect(t(".success"))
        else
          redirect_to settings_profile_path, notice: t(".email_change_initiated")
        end
      else
        error_message = @user.errors.any? ? @user.errors.full_messages.to_sentence : t(".email_change_failed")
        redirect_to settings_profile_path, alert: error_message
      end
    else
      was_ai_enabled = @user.ai_enabled
      @user.update!(user_params.except(:redirect_to, :delete_profile_image))
      @user.profile_image.purge if should_purge_profile_image?

      # Add a special notice if AI was just enabled
      notice = if !was_ai_enabled && @user.ai_enabled
        "AI Assistant has been enabled successfully."
      else
        t(".success")
      end

      respond_to do |format|
        format.html { handle_redirect(notice) }
        format.json { head :ok }
      end
    end
  end

  def reset
    FamilyResetJob.perform_later(Current.family)
    redirect_to settings_profile_path, notice: t(".success")
  end

  def reset_with_sample_data
    FamilyResetJob.perform_later(Current.family, load_sample_data_for_email: @user.email)
    redirect_to settings_profile_path, notice: t(".success")
  end

  def destroy
    if @user.deactivate
      Current.session.destroy
      redirect_to root_path, notice: t(".success")
    else
      redirect_to settings_profile_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  def rule_prompt_settings
    @user.update!(rule_prompt_settings_params)
    redirect_back_or_to settings_profile_path
  end

  private
    def handle_redirect(notice)
      redirect_token = user_params[:redirect_to]

      return if handle_partner_redirect(redirect_token, notice)

      case redirect_token
      when "onboarding_preferences"
        redirect_to preferences_onboarding_path
      when "home"
        redirect_to root_path
      when "preferences"
        redirect_to settings_preferences_path, notice: notice
      when "goals"
        redirect_to goals_onboarding_path
      when "trial"
        redirect_to trial_onboarding_path
      else
        redirect_to settings_profile_path, notice: notice
      end
    end

    def handle_partner_redirect(token, notice)
      return false if token.blank?

      if (match = token.match(/\A(chancen|partner)_onboarding_next_step:(?<current>[a-z_]+)\z/))
        redirect_partner_to_next_step(match[:current], notice)
        return true
      end

      if (match = token.match(/\A(chancen|partner)_onboarding_(?<target>[a-z_]+)\z/))
        redirect_partner_to_step(match[:target], notice)
        return true
      end

      false
    end

    def redirect_partner_to_next_step(current_step, notice)
      partner, route_params = partner_for_redirect(notice)
      return true unless partner

      next_path = Partners::OnboardingSteps.next_step_path(
        partner: partner,
        current_key: current_step,
        view_context: self,
        route_params: route_params
      )

      if next_path.present?
        redirect_to next_path
      else
        redirect_to root_path
      end

      true
    end

    def redirect_partner_to_step(target_step, notice)
      partner, route_params = partner_for_redirect(notice)
      return true unless partner

      if Partners::OnboardingSteps.include?(partner, target_step)
        path = Partners::OnboardingSteps.path_for(
          partner: partner,
          key: target_step,
          view_context: self,
          route_params: route_params
        )

        if path.present?
          redirect_to path
          return true
        end
      end

      next_path = Partners::OnboardingSteps.next_step_path(
        partner: partner,
        current_key: target_step,
        view_context: self,
        route_params: route_params
      )

      if next_path.present?
        redirect_to next_path
      else
        redirect_to root_path
      end

      true
    end

    def partner_for_redirect(notice)
      partner_key = active_partner_key

      if partner_key.blank?
        redirect_to settings_profile_path, notice: notice
        return [ nil, nil ]
      end

      partner = Partners.find(partner_key) || Partners.default
      [ partner, { partner_key: partner_key } ]
    end

    def should_purge_profile_image?
      user_params[:delete_profile_image] == "1" &&
        user_params[:profile_image].blank?
    end

    def email_changed?
      user_params[:email].present? && user_params[:email] != @user.email
    end

    def rule_prompt_settings_params
      params.require(:user).permit(:rule_prompt_dismissed_at, :rule_prompts_disabled)
    end

    def user_params
      params.require(:user).permit(
        :first_name, :last_name, :email, :profile_image, :redirect_to, :delete_profile_image, :onboarded_at,
        :show_sidebar, :default_period, :default_account_order, :show_ai_sidebar, :ai_enabled, :theme, :set_onboarding_preferences_at, :set_onboarding_goals_at,
        family_attributes: [ :name, :currency, :country, :locale, :date_format, :timezone, :id ],
        goals: [],
        partner_metadata: {}
      )
    end

    def set_user
      @user = Current.user
    end

    def ensure_admin
      redirect_to settings_profile_path, alert: I18n.t("users.reset.unauthorized") unless Current.user.admin?
    end
end
