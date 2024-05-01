# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module API
    module OpenTelemetry
      # Create custom span based on current last span
      #
      # Wrap OpenTelemetry function OpenTelemetry.tracer_provider.tracer.in_span
      #
      # === Argument:
      #
      # * +name+ - (int, default 3000) the maximum time to wait in milliseconds
      # * +attributes+ - (hash, default nil)
      # * +links+ - (string, default nil)
      # * +start_timestamp+ - (int, default nil)
      # * +kind+ - (symbol, default nil)
      #
      # === Example:
      #
      #   SolarWindsAPM::API.in_span('custom_span') do |span|
      #     url = URI.parse("http://www.google.ca/")
      #     req = Net::HTTP::Get.new(url.to_s)
      #     res = Net::HTTP.start(url.host, url.port) {|http| http.request(req)}
      #   end
      #
      # === Returns:
      # * value returned by block
      #
      def in_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil, &block)
        if block.nil?
          SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] please provide block when using in_span function" }
          return
        end

        SolarWindsAPM.logger.debug do
          "[#{name}/#{__method__}] solarwinds_apm in_span with OTEL_SERVICE_NAME #{ENV.fetch('OTEL_SERVICE_NAME', nil)}"
        end
        current_tracer = ::OpenTelemetry.tracer_provider.tracer(ENV.fetch('OTEL_SERVICE_NAME', nil))
        current_tracer.in_span(name, attributes: attributes, links: links, start_timestamp: start_timestamp, kind: kind, &block)
      end
    end
  end
end
