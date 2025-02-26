# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Metrics
    class Counter
      # counter = Counter.new
      # counter[:request_count].update(1)
      def initialize
        @meter = ::OpenTelemetry.meter_provider.meter("sw.apm.sampling.metrics")

        @counter = {
          request_count: @meter.create_counter("trace.service.request_count"),
          sample_count: @meter.create_counter("trace.service.samplecount"),
          trace_count: @meter.create_counter("trace.service.tracecount"),
          through_trace_count: @meter.create_counter("trace.service.through_trace_count"),
          triggered_trace_count: @meter.create_counter("trace.service.triggered_trace_count"),
          token_bucket_exhaustion_count: @meter.create_counter("trace.service.tokenbucket_exhaustion_count")
        }
      end

      def [](key)
        @counter[key]
      end
    end
  end
end
