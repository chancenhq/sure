class ConsentsController < ApplicationController
  layout "auth"
  skip_authentication

  SUPPORTED_COUNTRIES = [
    [ "Kenya", "KE" ],
    [ "Rwanda", "RW" ],
    [ "South Africa", "ZA" ],
    [ "Ghana", "GH" ]
  ].freeze

  def show
  end

  def create
    country = params[:country].to_s.upcase
    if SUPPORTED_COUNTRIES.map(&:last).include?(country)
      session[:pending_country] = country
    end
    session[:consent_accepted] = true
    redirect_to new_session_path
  end
end
