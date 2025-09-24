# frozen_string_literal: true

# © 2025 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Instrumentation
    module Rack
      module Middlewares
        module Patch
          # rubocop:disable Lint/UnusedMethodArgument
          def on_commit(request, response)
            response_propagators&.each do |propagator|
              propagator.inject(response.headers)
            rescue StandardError => e
              ::OpenTelemetry.handle_error(message: 'Unable to inject response propagation headers', exception: e)
            end
          rescue StandardError => e
            ::OpenTelemetry.handle_error(exception: e)
          end
          # rubocop:enable Lint/UnusedMethodArgument
        end
      end
    end
  end
end

OpenTelemetry::Instrumentation::Rack::Middlewares::Stable::EventHandler.prepend(SolarWindsAPM::Instrumentation::Rack::Middlewares::Patch) if defined?(OpenTelemetry::Instrumentation::Rack::Middlewares::Stable::EventHandler)
OpenTelemetry::Instrumentation::Rack::Middlewares::Old::EventHandler.prepend(SolarWindsAPM::Instrumentation::Rack::Middlewares::Patch) if defined?(OpenTelemetry::Instrumentation::Rack::Middlewares::Old::EventHandler)
OpenTelemetry::Instrumentation::Rack::Middlewares::Dup::EventHandler.prepend(SolarWindsAPM::Instrumentation::Rack::Middlewares::Patch) if defined?(OpenTelemetry::Instrumentation::Rack::Middlewares::Dup::EventHandler)
