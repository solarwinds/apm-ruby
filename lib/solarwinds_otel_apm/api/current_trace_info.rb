#--
# Copyright (c) SolarWinds, LLC.
# All rights reserved.
#++
module SolarWindsOTelAPM
  module API
    module CurrentTraceInfo
      # Creates an instance of {TraceInfo} with instance methods {TraceInfo#trace_id},
      # {TraceInfo#span_id}, {TraceInfo#trace_flags}, {TraceInfo#for_log},
      # and {TraceInfo#hash_for_log}.
      #
      # === Example:
      #
      #   trace = SolarWindsOTelAPM::API.current_trace_info
      #   trace.for_log        # 'trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=01 service.name=otel_service_name' or '' depends on Config
      #   trace.hash_for_log   # { trace_id: '7435a9fe510ae4533414d425dadf4e18',
      #                            span_id: '49e60702469db05f',
      #                            trace_flags: '',
      #                            service.name: 'otel_service_name' }  or {} depends on Config
      #
      #   The <tt>SolarWindsOTelAPM::Config[:log_traceId]</tt> configuration setting for automatic trace context in logs affects the 
      #   return value of methods in this module.
      #
      #   The following options are available:
      #   :never    (default)
      #   :sampled  only include the Trace ID of sampled requests
      #   :traced   include the Trace ID for all traced requests
      #   :always   always add a Trace ID, it will be
      #             "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 service.name=otel_service_name"
      #             when there is no tracing context.
      #
      # Configure trace info injection with lograge:
      #
      #    Lograge.custom_options = lambda do |event|
      #       SolarWindsOTelAPM::API.current_trace_info.hash_for_log
      #    end
      #
      def current_trace_info
        TraceInfo.new
      end

      # @attr trace_id
      # @attr span_id
      # @attr trace_flags
      class TraceInfo
        attr_reader :tracestring, :trace_id, :span_id, :trace_flags, :do_log

        REGEXP = /^(?<tracestring>(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))$/.freeze
        SQL_REGEX=/\/\*\s*traceparent=.*\*\/\s*/.freeze

        private_constant :REGEXP

        def initialize
          @trace_id, @span_id, @trace_flags = current_span
          @service_name = ENV['OTEL_SERVICE_NAME']
          @tracestring  = "00-#{@trace_id}-#{@span_id}-#{@trace_flags}"
          @do_log = log? # true if the tracecontext should be added to logs
          @do_sql = sql? # true if the tracecontext should be added to sql
        end

        # for_log returns a string in the format
        # 'trace_id=<trace_id> span_id=<span_id> trace_flags=<trace_flags>' or ''.
        # 
        # An empty string is returned depending on the setting for
        # <tt>SolarWindsOTelAPM::Config[:log_traceId]</tt>, which can be :never,
        # :sampled, :traced, or :always.
        #
        # === Argument:
        #
        # === Example:
        #
        #   trace = SolarWindsOTelAPM::API.current_trace_info
        #   trace.for_log  # 'trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=01 service.name=otel_service_name' or '' depends on Config
        #
        # === Returns:
        # * String
        #
        def for_log
          @for_log ||= @do_log ? "trace_id=#{@trace_id} span_id=#{@span_id} trace_flags=#{@trace_flags} service.name=#{@service_name}" : ''
        end

        # Construct the trace_id and span_id for log insertion.
        #
        # === Argument:
        #
        # === Example:
        #
        #   trace = SolarWindsOTelAPM::API.current_trace_info
        #   trace.hash_for_log   # { trace_id: '7435a9fe510ae4533414d425dadf4e18',
        #                            span_id: '49e60702469db05f',
        #                            trace_flags: 01,
        #                            service.name: 'otel_service_name' }  or {} depends on Config
        #   
        #   For lograge:
        #   Lograge.custom_options = lambda do |event|
        #     SolarWindsOTelAPM::API.current_trace_info.hash_for_log
        #   end
        #
        # === Returns:
        # * Hash
        #
        def hash_for_log
          @hash_for_log = {}
          @hash_for_log = {trace_id: @trace_id, span_id: @span_id, trace_flags: @trace_flags, service_name: @service_name} if @do_log
        end

        private

        def current_span
          span     = ::OpenTelemetry::Trace.current_span if defined?(::OpenTelemetry::Trace)
          trace_id = span.context.hex_trace_id
          span_id  = span.context.hex_span_id
          trace_flags = span.context.trace_flags.sampled?? '01' : '00'
          [trace_id, span_id, trace_flags]
        end

        # if true the trace info should be added to the log message
        def log?
          case SolarWindsOTelAPM::Config[:log_traceId]
          when :never, nil
            false
          when :always
            true
          when :traced
            valid?(@tracestring)
          when :sampled
            sampled?(@tracestring)
          end
        end

        # if true the trace info should be added to the sql query
        def sql?
          SolarWindsOTelAPM::Config[:tag_sql] && SolarWindsOTelAPM::TraceString.sampled?(@tracestring)
        end

        # un-initialized (all 0 trace-id) tracestrings are not valid
        def valid?(tracestring)
          matches = REGEXP.match(tracestring)

          matches && matches[:trace_id] != ("0" * 32)
        end

        def sampled?(tracestring)
          matches = REGEXP.match(tracestring)

          matches && matches[:flags][-1].to_i & 1 == 1
        end

        def split(tracestring)
          REGEXP.match(tracestring)
        end
      end
    end
  end
end
