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

    def first_step_path(partner:, view_context:, route_params: {})
      key = enabled_keys(partner).first
      definition = STEP_DEFINITIONS[key]
      return unless definition

      definition[:path].call(view_context, route_params)
    end

    def step_name(view_context:, partner:, key:)
      partner&.translation(:onboarding, :nav, key, default: view_context.t("partner_onboardings.nav.#{key}"))
    end
  end
end
