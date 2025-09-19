# SAFETY: Only operates in development/test environments to prevent data loss
class Demo::DataCleaner
  SAFE_ENVIRONMENTS = %w[development test].freeze
  OVERRIDE_ENV_VAR = "ALLOW_DEMO_DATA_OVERRIDE".freeze

  def self.override_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(OVERRIDE_ENV_VAR, false))
  end

  def initialize(force: self.class.override_enabled?)
    ensure_safe_environment!(force: force)
  end

  # Main entry point for destroying all demo data
  def destroy_everything!
    ApplicationRecord.no_touching do
      Family.destroy_all
      Setting.destroy_all
      InviteCode.destroy_all
      ExchangeRate.destroy_all
      Security.destroy_all
      Security::Price.destroy_all
    end

    puts "Data cleared"
  end

  private

    def ensure_safe_environment!(force: false)
      return if force || SAFE_ENVIRONMENTS.include?(Rails.env)

      raise SecurityError,
            "Demo::DataCleaner can only be used in #{SAFE_ENVIRONMENTS.join(', ')} environments. Current: #{Rails.env}"
    end
end
