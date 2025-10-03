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

    module_function

    def enabled_keys(partner)
      partner_steps = Array(partner&.onboarding_steps).presence || DEFAULT_KEYS
      partner_steps.map(&:to_s) & STEP_DEFINITIONS.keys
    end

    def include?(partner, key)
      enabled_keys(partner).include?(key.to_s)
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

    def path_for(partner:, key:, view_context:, route_params: {})
      definition = STEP_DEFINITIONS[key.to_s]
      return unless definition

      definition[:path].call(view_context, route_params)
    end

    def first_step_path(partner:, view_context:, route_params: {})
      key = enabled_keys(partner).first
      path_for(partner: partner, key: key, view_context: view_context, route_params: route_params) if key
    end

    def next_step_key(partner:, current_key:)
      keys = enabled_keys(partner)
      string_key = current_key.to_s
      index = keys.index(string_key)
      return keys[index + 1] if index

      default_index = DEFAULT_KEYS.index(string_key)
      return unless default_index

      keys.find do |key|
        default_position = DEFAULT_KEYS.index(key)
        default_position && default_position > default_index
      end
    end

    def previous_step_key(partner:, current_key:)
      keys = enabled_keys(partner)
      index = keys.index(current_key.to_s)
      return unless index && index.positive?

      keys[index - 1]
    end

    def next_step_path(partner:, current_key:, view_context:, route_params: {})
      next_key = next_step_key(partner: partner, current_key: current_key)
      return unless next_key

      path_for(partner: partner, key: next_key, view_context: view_context, route_params: route_params)
    end

    def previous_step_path(partner:, current_key:, view_context:, route_params: {})
      previous_key = previous_step_key(partner: partner, current_key: current_key)
      return unless previous_key

      path_for(partner: partner, key: previous_key, view_context: view_context, route_params: route_params)
    end

    def step_name(view_context:, partner:, key:)
      partner&.translation(:onboarding, :nav, key, default: view_context.t("partner_onboardings.nav.#{key}"))
    end
  end
end
