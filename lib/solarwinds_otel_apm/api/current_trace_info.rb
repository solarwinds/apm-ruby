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
      #   trace.for_log        # 'trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=01' or '' depends on Config
      #   trace.hash_for_log   # { trace_id: '7435a9fe510ae4533414d425dadf4e18',
      #                            span_id: '49e60702469db05f',
      #                            trace_flags: ''}  or {} depends on Config
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
          @trace_id     = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)
          @span_id      = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)
          @trace_flags  = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_TRACE_FLAG)
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
        def for_log
          @for_log ||= @do_log ? "trace_id=#{@trace_id} span_id=#{@span_id} trace_flags=#{@trace_flags} service.name=#{@service_name}" : ''
        end

        def hash_for_log
          @hash_for_log = {}
          @hash_for_log = {trace_id: @trace_id, span_id: @span_id, trace_flags: @trace_flags, service_name: @service_name} if @do_log
        end

        def for_sql
          @for_sql ||= @do_sql ? "/*traceparent='#{@tracestring}'*/" : ''
        end

        ##
        # add_traceparent_to_sql
        #
        # returns the sql with "/*traceparent='#{@tracestring}'*/" prepended
        # and adds the QueryTag kv to kvs
        #
        def add_traceparent_to_sql(sql, kvs)
          sql = sql.gsub(SQL_REGEX, '') # remove if it was added before

          unless for_sql.empty?
            kvs[:QueryTag] = for_sql
            return "#{for_sql}#{sql}"
          end

          sql
        end

        private

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
