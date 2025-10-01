module Partners
  class Registry
    include Enumerable

    def initialize(config = {})
      @definitions = (config || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = Partners::Definition.new(key, value)
      end
    end

    def each(&block)
      @definitions.values.each(&block)
    end

    def find(key)
      return nil if key.blank?

      @definitions[key.to_s]
    end

    def default
      @definitions.values.first
    end

    def keys
      @definitions.keys
    end
  end
end
