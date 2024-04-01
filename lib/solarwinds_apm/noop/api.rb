# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

####
# noop version of SolarWindsAPM::API
#
module SolarWindsAPM
  # API
  module API 
  end

  # Tracing
  module Tracing
    # (wait_milliseconds=3000, integer_response: false)
    def solarwinds_ready?(*_args, **options)
      options && options[:integer_response] ? 0 : false
    end
  end

  # CurrentTraceInfo
  module CurrentTraceInfo
    def current_trace_info
      TraceInfo.new
    end

    class TraceInfo
      attr_reader :tracestring, :trace_id, :span_id, :trace_flags, :do_log

      REGEXP = /^(?<tracestring>(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))$/.freeze # rubocop:disable Style/RedundantFreeze
      private_constant :REGEXP

      def initialize
        @trace_id, @span_id, @trace_flags, @tracestring = current_span
        @service_name = ENV['OTEL_SERVICE_NAME']
        @do_log = log?
      end

      def for_log
        ''
      end

      def hash_for_log
        {}
      end

      private

      def current_span
        %w[00000000000000000000000000000000 0000000000000000 00 00-00000000000000000000000000000000-0000000000000000-00]
      end

      def log?
        :never
      end

      def valid?(*)
        false
      end

      def sampled?(*)
        false
      end

      def split(*)
        REGEXP.match('00-00000000000000000000000000000000-0000000000000000-00')
      end
    end
  end

  # CustomMetrics
  module CustomMetrics
    def increment_metric(*) = false

    def summary_metric(*) = false
  end

  # OpenTelemetry
  module OpenTelemetry
    def in_span(*); end
  end

  # TransactionName
  module TransactionName
    def set_transaction_name(*)
      false
    end
  end
end

SolarWindsAPM::API.extend(SolarWindsAPM::Tracing)
SolarWindsAPM::API.extend(SolarWindsAPM::CurrentTraceInfo)
SolarWindsAPM::API.extend(SolarWindsAPM::CustomMetrics)
SolarWindsAPM::API.extend(SolarWindsAPM::OpenTelemetry)
SolarWindsAPM::API.extend(SolarWindsAPM::TransactionName)
