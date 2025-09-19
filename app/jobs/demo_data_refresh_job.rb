class DemoDataRefreshJob < ApplicationJob
  queue_as :scheduled

  def perform
    return unless refresh_enabled?

    Demo::Generator
      .new(allow_production: allow_production?)
      .generate_default_data!(email: refresh_email)
  end

  private

    def refresh_enabled?
      return true unless Rails.env.production?

      Demo::DataCleaner.override_enabled?
    end

    def allow_production?
      Demo::DataCleaner.override_enabled?
    end

    def refresh_email
      ENV.fetch("DEMO_DATA_REFRESH_EMAIL", "user@example.com")
    end
end
