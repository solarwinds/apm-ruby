module SolarWindsAPM
  module OpenTelemetry
    # SolarWindsTxnNameManager
    class TxnNameManager
      attr_accessor :root_context

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
    end
  end
end
