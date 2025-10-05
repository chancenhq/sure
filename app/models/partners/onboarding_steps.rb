module Partners
  module OnboardingSteps
    STEP_DEFINITIONS = {
      "setup" => {
        path: ->(context, params) { context.partner_onboarding_path(params) },
        completion: ->(user) { user.first_name.present? }
      },
      "preferences" => {
        path: ->(context, params) { context.preferences_partner_onboarding_path(params) },
        completion: ->(user) { user.set_onboarding_preferences_at.present? }
      },
      "goals" => {
        path: ->(context, params) { context.goals_partner_onboarding_path(params) },
        completion: ->(user) { user.set_onboarding_goals_at.present? }
      },
      "trial" => {
        path: ->(context, params) { context.trial_partner_onboarding_path(params) },
        completion: ->(user) { user.onboarded? }
      }
    }.freeze

    DEFAULT_KEYS = STEP_DEFINITIONS.keys.freeze
    AUTO_COMPLETABLE_KEYS = %w[setup preferences].freeze

    FAMILY_FALLBACKS = {
      locale: "en",
      currency: "USD",
      country: "US",
      date_format: "%Y-%m-%d"
    }.freeze

    module_function

    def enabled_keys(partner)
      partner_steps = Array(partner&.onboarding_steps).presence || DEFAULT_KEYS
      partner_steps.map(&:to_s) & STEP_DEFINITIONS.keys
    end

    def include?(partner, key)
      enabled_keys(partner).include?(key.to_s)
    end

    def next_step_key(partner, current_step)
      keys = enabled_keys(partner)
      index = keys.index(current_step.to_s)
      return unless index

      keys[index + 1]
    end

    def previous_step_key(partner, current_step)
      keys = enabled_keys(partner)
      index = keys.index(current_step.to_s)
      return unless index
      return if index.zero?

      keys[index - 1]
    end

    def build_steps(partner:, user:, view_context:, route_params: {})
      enabled_keys(partner).map.with_index(1) do |key, index|
        definition = STEP_DEFINITIONS[key]
        next unless definition

        {
          key: key.to_sym,
          name: step_name(view_context: view_context, partner: partner, key: key),
          path: definition[:path].call(view_context, route_params),
          is_complete: definition[:completion].call(user),
          step_number: index
        }
      end.compact
    end

    def first_step_path(partner:, view_context:, route_params: {})
      key = enabled_keys(partner).first
      definition = STEP_DEFINITIONS[key]
      return unless definition

      definition[:path].call(view_context, route_params)
    end

    def next_step_path(partner:, current_step:, view_context:, route_params: {})
      key = next_step_key(partner, current_step)
      step_path(key, view_context: view_context, route_params: route_params)
    end

    def previous_step_path(partner:, current_step:, view_context:, route_params: {})
      key = previous_step_key(partner, current_step)
      step_path(key, view_context: view_context, route_params: route_params)
    end

    def auto_complete_missing_steps!(partner:, user:)
      missing_keys = AUTO_COMPLETABLE_KEYS - enabled_keys(partner)

      user.with_lock do
        apply_user_defaults!(user, partner)
        return if missing_keys.empty?

        missing_keys.each do |key|
          case key
          when "setup"
            auto_complete_setup_step!(user)
          when "preferences"
            auto_complete_preferences_step!(user, partner)
          end
        end
      end
    end

    def step_name(view_context:, partner:, key:)
      partner&.translation(:onboarding, :nav, key, default: view_context.t("partner_onboardings.nav.#{key}"))
    end

    def step_path(key, view_context:, route_params: {})
      definition = STEP_DEFINITIONS[key.to_s]
      return unless definition

      definition[:path].call(view_context, route_params)
    end

    def auto_complete_setup_step!(user)
      return if user.first_name.present?

      defaults = setup_defaults_for(user)
      user.update!(defaults) if defaults.any?
    end

    def auto_complete_preferences_step!(user, partner)
      attrs = {}
      attrs[:set_onboarding_preferences_at] = Time.current unless user.set_onboarding_preferences_at?
      attrs[:theme] = "system" if user.theme.blank?

      family_attrs = preferences_family_defaults_for(user, partner: partner)

      user.update!(attrs) if attrs.any?
      if user.family && family_attrs.any?
        user.family.update!(family_attrs)
      end
    end

    def setup_defaults_for(user)
      first_name = user.first_name.presence || default_first_name_for(user)
      last_name = user.last_name.presence || default_last_name_for(user)

      result = {}
      result[:first_name] = first_name if user.first_name.blank? && first_name.present?
      result[:last_name] = last_name if user.last_name.blank? && last_name.present?
      result
    end

    def preferences_family_defaults_for(user, partner:)
      family = user.family
      return {} unless family

      partner_defaults = partner&.default_metadata || {}
      defaults = {}

      if family.locale.blank?
        defaults[:locale] = partner_defaults["locale"].presence || FAMILY_FALLBACKS[:locale]
      end

      if family.currency.blank?
        defaults[:currency] = partner_defaults["currency"].presence || FAMILY_FALLBACKS[:currency]
      end

      if family.date_format.blank?
        defaults[:date_format] = partner_defaults["date_format"].presence || FAMILY_FALLBACKS[:date_format]
      end

      if family.country.blank?
        defaults[:country] = partner_defaults["country"].presence ||
          user.partner_attribute(:country).presence ||
          FAMILY_FALLBACKS[:country]
      end

      defaults
    end

    def apply_user_defaults!(user, partner)
      defaults = partner&.user_defaults || {}
      return if defaults.blank?

      updates = {}
      defaults.each do |attribute, value|
        attribute_name = attribute.to_s
        setter = "#{attribute_name}="
        next unless user.respond_to?(setter)
        current = user.respond_to?(attribute_name) ? user.public_send(attribute_name) : nil
        next if current == value

        updates[attribute_name] = value
      end

      user.update!(updates) if updates.any?
    end

    def default_first_name_for(user)
      local_part = user.email.to_s.split("@").first.to_s
      local_part.gsub(/[^a-zA-Z]+/, " ").strip.titleize.presence
    end

    def default_last_name_for(_user)
      nil
    end
  end
end
