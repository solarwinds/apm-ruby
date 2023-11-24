# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module API
    module CurrentTraceInfo
      # Creates an instance of {TraceInfo} with instance methods:<br>
      # {TraceInfo#trace_id}<br>
      # {TraceInfo#span_id}<br>
      # {TraceInfo#trace_flags}<br>
      # {TraceInfo#for_log}<br>
      # {TraceInfo#hash_for_log}
      # 
      # The <tt>SolarWindsAPM::Config[:log_traceId]</tt> configuration setting for automatic trace context in logs affects the 
      # return value of methods in this module.
      #
      # The following options are available:<br>
      # <tt>:never</tt>    (default)<br>
      # <tt>:sampled</tt>  only include the Trace ID of sampled requests<br>
      # <tt>:traced</tt>   include the Trace ID for all traced requests<br>
      # <tt>:always</tt>   always add a Trace ID, it will be "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name=otel_service_name" when there is no tracing context.
      #
      # === Example:
      #
      #   trace = SolarWindsAPM::API.current_trace_info
      #   trace.for_log        # 'trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=01 resource.service.name=otel_service_name' or '' depends on Config
      #   trace.hash_for_log   # { trace_id: '7435a9fe510ae4533414d425dadf4e18',
      #                            span_id: '49e60702469db05f',
      #                            trace_flags: '',
      #                            resource.service.name: 'otel_service_name' }  or {} depends on Config
      #
      #
      # Configure trace info injection with lograge:
      #
      #    Lograge.custom_options = lambda do |event|
      #       SolarWindsAPM::API.current_trace_info.hash_for_log
      #    end
      #
      def current_trace_info
        TraceInfo.new
      end

      # @attr [String] tracestring
      # @attr [String] trace_id
      # @attr [String] span_id
      # @attr [String] trace_flags
      # @attr [Boolean] do_log
      class TraceInfo
        attr_reader :tracestring, :trace_id, :span_id, :trace_flags, :do_log

        REGEXP = /^(?<tracestring>(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))$/
        private_constant :REGEXP

        def initialize
          @trace_id, @span_id, @trace_flags, @tracestring = current_span
          @service_name = ENV['OTEL_SERVICE_NAME']
          @do_log = log? # true if the tracecontext should be added to logs
        end

        # for_log returns a string in the format
        # 'trace_id=<trace_id> span_id=<span_id> trace_flags=<trace_flags>' or empty string.
        # 
        # An empty string is returned depending on the setting for
        # <tt>SolarWindsAPM::Config[:log_traceId]</tt>, which can be :never,
        # :sampled, :traced, or :always.
        #
        # === Example:
        #
        #   trace = SolarWindsAPM::API.current_trace_info
        #   trace.for_log  # 'trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=01 resource.service.name=otel_service_name' or '' depends on Config
        #
        # === Returns:
        # * String
        #
        def for_log
          @for_log ||= @do_log ? "trace_id=#{@trace_id} span_id=#{@span_id} trace_flags=#{@trace_flags} resource.service.name=#{@service_name}" : ''
        end

        # Construct the trace_id, span_id, trace_flags and resource.service.name for log insertion.
        #
        # === Example:
        #
        #   trace = SolarWindsAPM::API.current_trace_info
        #   trace.hash_for_log   # { trace_id: '7435a9fe510ae4533414d425dadf4e18',
        #                            span_id: '49e60702469db05f',
        #                            trace_flags: 01,
        #                            resource.service.name: 'otel_service_name' }  or {} depends on Config
        #   
        #   # For lograge:
        #   Lograge.custom_options = lambda do |event|
        #     SolarWindsAPM::API.current_trace_info.hash_for_log
        #   end
        #
        # === Returns:
        # * Hash
        #
        def hash_for_log
          @hash_for_log = @do_log ? {'trace_id' => @trace_id, 'span_id' => @span_id, 'trace_flags' => @trace_flags, 'resource.service.name' => @service_name} : {}
        end

        private

        def current_span
          span     = ::OpenTelemetry::Trace.current_span if defined?(::OpenTelemetry::Trace)
          trace_id = span.context.hex_trace_id
          span_id  = span.context.hex_span_id
          trace_flags = span.context.trace_flags.sampled?? '01' : '00'
          tracestring = "00-#{trace_id}-#{span_id}-#{trace_flags}"
          [trace_id, span_id, trace_flags, tracestring]
        end

        # if true the trace info should be added to the log message
        def log?
          case SolarWindsAPM::Config[:log_traceId]
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
