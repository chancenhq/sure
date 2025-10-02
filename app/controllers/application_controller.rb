class ApplicationController < ActionController::Base
  include RestoreLayoutPreferences, Onboardable, Localize, AutoSync, Authentication, Invitable,
          SelfHostable, StoreLocation, Impersonatable, Breadcrumbable,
          FeatureGuardable, Notifiable

  include Pagy::Backend

  helper_method :current_partner, :active_partner_key

  before_action :detect_os
  before_action :set_default_chat
  before_action :set_active_storage_url_options
  before_action :enforce_intro_settings_scope

  private
    def detect_os
      user_agent = request.user_agent
      @os = case user_agent
      when /Windows/i then "windows"
      when /Macintosh/i then "mac"
      when /Linux/i then "linux"
      when /Android/i then "android"
      when /iPhone|iPad/i then "ios"
      else ""
      end
    end

    def current_partner
      return @partner if defined?(@partner) && @partner.present?
      return @current_partner if defined?(@current_partner)

      key = Current.user&.partner_key
      @current_partner = Partners.find(key) if key.present?
    end

    def active_partner_key
      (defined?(@partner) && @partner&.key) || current_partner&.key
    end

    # By default, we show the user the last chat they interacted with
    def set_default_chat
      @last_viewed_chat = Current.user&.last_viewed_chat
      @chat = @last_viewed_chat
    end

    def set_active_storage_url_options
      ActiveStorage::Current.url_options = {
        protocol: request.protocol,
        host: request.host,
        port: request.optional_port
      }
    end

    def enforce_intro_settings_scope
      return unless Current.user&.intro?
      return unless params[:controller]&.start_with?("settings/")
      return if params[:controller] == "settings/profiles"

      redirect_to settings_profile_path and return
    end
end
