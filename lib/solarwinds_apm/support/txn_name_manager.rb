module SolarWindsAPM
  module OpenTelemetry
    # SolarWindsTxnNameManager
    class TxnNameManager
      def initialize
        @cache = {}
        @root_context_h = {}
        @mutex = Mutex.new
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

      def set_root_context_h(key, value)
        @mutex.synchronize do
          @root_context_h[key] = value
        end
      end

      def get_root_context_h(key)
        @root_context_h[key]
      end

      def delete_root_context_h(key)
        @mutex.synchronize do
          @root_context_h.delete(key)
        end
      end
    end
  end
end
