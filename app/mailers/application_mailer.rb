class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(
    ENV.fetch("EMAIL_SENDER", "sender@sure.local"),
    "#{Rails.configuration.x.product_name} Finance"
  )
  layout "mailer"

  private
    def brand_name
      Rails.configuration.x.brand_name
    end

    def product_name
      Rails.configuration.x.product_name
    end

    def product_plus
      Rails.configuration.x.product_plus
    end
end
