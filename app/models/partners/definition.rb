module Partners
  class Definition
    USER_DEFAULT_KEYS = %w[ai_enabled ui_layout].freeze

    attr_reader :key

    def initialize(key, config)
      @key = key.to_s
      normalized_config =
        case config
        when Hash
          config
        else
          config.respond_to?(:to_h) ? config.to_h : {}
        end

      @config = (normalized_config || {}).deep_stringify_keys
    end

    def name
      @config["name"] || key.titleize
    end

    def type
      @config["type"]
    end

    def required_metadata_keys
      Array(@config.dig("metadata", "required")).map(&:to_s)
    end

    def default_metadata
      defaults = @config.dig("metadata", "defaults")
      normalized_defaults =
        case defaults
        when Hash
          defaults
        else
          defaults.respond_to?(:to_h) ? defaults.to_h : {}
        end

      metadata_defaults = (normalized_defaults || {}).deep_stringify_keys
      USER_DEFAULT_KEYS.each { |key| metadata_defaults.delete(key) }
      metadata_defaults
    end

    def onboarding_steps
      Array(@config.dig("onboarding", "steps")).map do |step|
        step.is_a?(Hash) ? step["key"].to_s : step.to_s
      end
    end

    def translation(*keys, default: nil, **options)
      I18n.t([ "partners", key, *keys.map(&:to_s) ].join("."), **{ default: default }.merge(options))
    end

    def user_defaults
      source_defaults = @config.dig("metadata", "defaults") || {}
      raw_defaults = {}
      source_defaults.each do |key, value|
        raw_defaults[key.to_s] = value
      end

      USER_DEFAULT_KEYS.each_with_object({}) do |key, memo|
        memo[key] = raw_defaults[key] if raw_defaults.key?(key)
      end
    end

  end
end
