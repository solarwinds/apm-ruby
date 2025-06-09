# frozen_string_literal: true

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
end

module NoopAPI
  # Tracing
  module Tracing
    # (wait_milliseconds=3000, integer_response: false)
    def solarwinds_ready?(_wait_milliseconds = 3000, integer_response: false)
      _noop = integer_response
      false
    end
  end

  # CurrentTraceInfo
  module CurrentTraceInfo
    def current_trace_info
      TraceInfo.new
    end

    class TraceInfo
      attr_reader :tracestring, :trace_id, :span_id, :trace_flags, :do_log

      def initialize
        @trace_id = '00000000000000000000000000000000'
        @span_id = '0000000000000000'
        @trace_flags = '00'
        @tracestring = '00-00000000000000000000000000000000-0000000000000000-00'
        @service_name = ''
        @do_log = :never
      end

      def for_log
        ''
      end

      def hash_for_log
        {}
      end
    end
  end

  # CustomMetrics
  module CustomMetrics
    def increment_metric(*)
      SolarWindsAPM.logger.warn { 'increment_metric have been deprecated. Please use opentelemetry metrics-sdk to log metrics data.' }
      false
    end

    def summary_metric(*)
      SolarWindsAPM.logger.warn { 'summary_metric have been deprecated. Please use opentelemetry metrics-sdk to log metrics data.' }
      false
    end
  end

  # OpenTelemetry
  module OpenTelemetry
    def in_span(*)
      yield if block_given?
    end
  end

  # TransactionName
  module TransactionName
    def set_transaction_name(*)
      true
    end
  end
end

SolarWindsAPM::API.extend(NoopAPI::Tracing)
SolarWindsAPM::API.extend(NoopAPI::CurrentTraceInfo)
SolarWindsAPM::API.extend(NoopAPI::CustomMetrics)
SolarWindsAPM::API.extend(NoopAPI::OpenTelemetry)
SolarWindsAPM::API.extend(NoopAPI::TransactionName)
