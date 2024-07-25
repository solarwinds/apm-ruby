# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # ServiceKeyChecker
  # It is a service that validate the service_key
  class ServiceKeyChecker
    def initialize(reporter, is_lambda)
      @reporter = reporter
      @is_lambda = is_lambda
    end

    def read_and_validate_service_key
      return '' unless @reporter == 'ssl'
      return '' if @is_lambda

      service_key = fetch_service_key
      if service_key.empty?
        SolarWindsAPM.logger.error { "[#{self.class}/#{__method__}] SW_APM_SERVICE_KEY not configured." }
        return ''
      end

      token, _, service_name = parse_service_key(service_key)
      if token.empty?
        SolarWindsAPM.logger.error do
          "[#{self.class}/#{__method__}] SW_APM_SERVICE_KEY problem. API Token in wrong format. Masked token: #{token[0..3]}...#{token[-4..]}"
        end
        return ''
      end

      # if no service_name from service_key, then the SW_APM_SERVICE_KEY is not right format, return
      if service_name.empty?
        ENV.delete('OTEL_SERVICE_NAME')
        SolarWindsAPM.logger.warn do
          "[#{self.class}/#{__method__}] SW_APM_SERVICE_KEY format problem. Service Name is missing."
        end
        return ''
      end

      service_name = transform_service_name(service_name)

      # check if otel_resource_service or otel_service_name has service name to override the original service name
      otel_resource_service_name = fetch_otel_resource_service_name
      service_name = transform_service_name(otel_resource_service_name) unless otel_resource_service_name.empty?

      otel_service_name = fetch_otel_service_name
      if otel_service_name.empty?
        ENV['OTEL_SERVICE_NAME'] = service_name
      else
        service_name = transform_service_name(otel_service_name)
      end

      "#{token}:#{service_name}"
    end

    private

    # since oboe_init_options init afte config, so [:service_key] will be present at this point
    def fetch_service_key
      ENV['SW_APM_SERVICE_KEY'] || SolarWindsAPM::Config[:service_key] || ''
    end

    def parse_service_key(service_key)
      match = service_key.match(/([^:]*)(:{0,1})(.*)/)
      return ['', '', ''] if match.nil?

      [match[1], match[2], match[3]]
    end

    # precedence: OTEL_SERVICE_NAME > OTEL_RESOURCE_ATTRIBUTES > service_key
    def fetch_otel_service_name
      ENV['OTEL_SERVICE_NAME'] || ''
    end

    def fetch_otel_resource_service_name
      ENV['OTEL_RESOURCE_ATTRIBUTES']&.split(',')&.find do |pair|
        key, value = pair.split('=')
        break value if key == 'service.name'
      end || ''
    end

    def transform_service_name(service_name)
      name_ = service_name.dup
      name_.downcase!
      name_.gsub!(/[^a-z0-9.:_-]/, '')
      name_ = name_[0..254]
      if name_ != service_name
        SolarWindsAPM.logger.warn do
          "[#{self.class}/#{__method__}] Service Name transformed from #{service_name} to #{name_}"
        end
      end

      name_
    end
  end
end
