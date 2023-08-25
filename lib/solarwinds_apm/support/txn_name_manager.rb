module SolarWindsAPM
  module OpenTelemetry
    # SolarWindsTxnNameManager
    class TxnNameManager
      def initialize
        @cache = {}
        @root_context = nil
      end

      def get(key)
        @cache[key]
      end

      def del(key)
        @cache.delete(key)
      end

      def set(key, value)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] current cache #{@cache.inspect}"}
        @cache[key] = value
      end

      alias []= set

      def set_root_context(value)
        @root_context = value
      end

      def get_root_context
        @root_context
      end
    end
  end
end
