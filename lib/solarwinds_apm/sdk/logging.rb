module SolarWindsAPM
  module SDK
    module Logging
      # Log an information event in the current span
      #
      # a possible use-case is to collect extra information during the execution of a request
      #
      # === Arguments:
      # * +kvs+   - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_info(kvs={})
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK::Logging will be depreciated soon. Please use SolarWindsAPM::API::Logging"}
        ::OpenTelemetry::Trace.current_span.add_event('event', attributes: kvs)
      end

      # Log an exception/error event in the current span
      #
      # this may be helpful to track problems when an exception is rescued
      #
      # === Arguments:
      # * +exception+ - an exception, must respond to :message and :backtrace
      # * +kvs+      - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_exception(exception, kvs={})
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK::Logging will be depreciated soon. Please use SolarWindsAPM::API::Logging"}
        ::OpenTelemetry::Trace.current_span.record_exception(exception, attributes: kvs)
      end
    end
  end
end
