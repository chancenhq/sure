class ChancenOnboardingsController < ApplicationController
  layout "wizard"

  before_action :set_user
  before_action :load_invitation
  before_action :set_kenyan_defaults, only: :preferences

  def show
  end

  def preferences
  end

  def kyc
    # Pre-populate fields from existing user data
    @kyc_data = {
      firstName: @user.display_name&.split&.first || "",
      lastName: @user.display_name&.split&.last || "",
      email: @user.email,
      countryCode: @user.family.country || "KE",
      mobilePhone: "",
      idType: "101", # Default to Kenyan ID
      address: ""
    }
  end

  def submit_kyc
    # Collect KYC data without persistence
    kyc_data = {
      firstName: params[:firstName],
      middleName: params[:middleName],
      lastName: params[:lastName],
      birthday: params[:birthday],
      gender: params[:gender],
      countryCode: params[:countryCode],
      mobilePhone: params[:mobilePhone],
      idType: params[:idType],
      idNumber: params[:idNumber],
      kraPin: params[:kraPin],
      email: params[:email],
      address: params[:address] || "",
      frontSidePhoto: encode_image(params[:frontSidePhoto]),
      backSidePhoto: encode_image(params[:backSidePhoto]),
      selfiePhoto: encode_image(params[:selfiePhoto])
    }

    # Validate required fields
    if validate_kyc_data(kyc_data)
      # Submit directly to Choice Bank API
      result = ChoiceBankApiService.submit_kyc(kyc_data, @user)
      
      if result[:success]
        # Store only the account ID in session, not sensitive data
        session[:choice_bank_account_id] = result[:account_id]
        redirect_to goals_chancen_onboarding_path, notice: "KYC information submitted successfully. Your Choice Bank account ID: #{result[:account_id]}"
      else
        flash.now[:alert] = result[:error] || "There was an error submitting your KYC information."
        @kyc_data = kyc_data.except(:frontSidePhoto, :backSidePhoto, :selfiePhoto)
        render :kyc
      end
    else
      flash.now[:alert] = "Please fill in all required fields."
      @kyc_data = kyc_data.except(:frontSidePhoto, :backSidePhoto, :selfiePhoto)
      render :kyc
    end
  rescue => e
    Rails.logger.error "KYC submission error: #{e.message}"
    redirect_to kyc_chancen_onboarding_path, alert: "There was an error processing your request. Please try again."
  end

  def goals
  end

  def trial
  end

  private
    def set_user
      @user = Current.user
    end

    def load_invitation
      @invitation = Current.family.invitations.accepted.find_by(email: Current.user.email)
    end

    def set_kenyan_defaults
      # Set Kenyan defaults if not already set
      @user.family.currency ||= "KES"
      @user.family.locale ||= "en"
      @user.family.date_format ||= "%d/%m/%Y"
      @user.family.country ||= "KE"
    end

    def validate_kyc_data(data)
      required_fields = [:firstName, :lastName, :birthday, :gender, :mobilePhone, 
                        :idType, :idNumber, :kraPin, :email, :frontSidePhoto, 
                        :backSidePhoto, :selfiePhoto]
      
      required_fields.all? { |field| data[field].present? }
    end

    def encode_image(file)
      return nil unless file.present?
      
      # Convert uploaded file to base64
      Base64.strict_encode64(file.read)
    rescue => e
      Rails.logger.error "Failed to encode image: #{e.message}"
      nil
    end
end
