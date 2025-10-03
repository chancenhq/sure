module Partners
  mattr_accessor :registry

  class << self
    def configure(config)
      normalized_config = deep_normalize(config || {})
      partners_config = normalized_config["partners"] || {}

      self.registry = Partners::Registry.new(partners_config)
    end

    def all
      self.registry ||= configure(load_config)
    end

    def find(key)
      all.find(key)
    end

    def default
      all.default
    end

    def reset!
      self.registry = nil
    end

    private

    def load_config
      Rails.application.config_for(:partners)
    rescue KeyError
      {}
    end

    def deep_normalize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), memo|
          memo[key.to_s] = deep_normalize(nested)
        end
      when Array
        value.map { |item| deep_normalize(item) }
      else
        if value.respond_to?(:to_h)
          deep_normalize(value.to_h)
        else
          value
        end
      end
    end
  end
end
