module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsTxnNameManager

      def initialize
        @cache = Hash.new
      end

      def get(key)
        @cache[key]
      end

      def del(key)
        @cache.delete(key)
      end

      def set(key, value)
        @cache[key] = value
      end

    end
  end
end
