# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module API
    module Tracing
      # Wait for SolarWinds to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running.
      # Usually SolarWinds doesn't block an application while it is starting up.
      #
      # === Argument:
      #
      # * +wait_milliseconds+ - (int, default 3000) the maximum time to wait in milliseconds
      #
      # === Example:
      #
      #   unless SolarWindsAPM::API.solarwinds_ready?(10_000)
      #     Logger.info "SolarWindsAPM not ready after 10 seconds, no metrics will be sent"
      #   end
      #
      # === Returns:
      # * Boolean
      #
      def solarwinds_ready?(wait_milliseconds = 3000, integer_response: false)
        unless integer_response.nil?
          SolarWindsAPM.logger.warn do
            'Deprecation: solarwinds_ready? no longer accept integer_response parameters. This function call will be removed in next release.'
          end
        end

        root_sampler = ::OpenTelemetry.tracer_provider.sampler.instance_variable_get(:@root)
        is_ready = root_sampler.wait_until_ready(wait_milliseconds / 1000)
        puts "is_ready: #{is_ready}"
        !!is_ready
      end
    end
  end
end
