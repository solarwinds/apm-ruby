# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # OTLPEndPoint
  class OTLPEndPoint
    SWO_APM_ENDPOINT_REGEX = /^apm\.collector\.([a-z]{2}-\d{2})\.([^.]+)\.solarwinds\.com(?::\d+)?$/
    SWO_APM_ENDPOINT_DEFAULT = 'apm.collector.na-01.cloud.solarwinds.com:443'

    SWO_OTLP_GENERAL_ENDPOINT_REGEX = %r{^https://otel\.collector\.[a-z0-9-]+\.[a-z0-9-]+\.solarwinds\.com(?::\d+)?$}
    SWO_OTLP_SIGNAL_ENDPOINT_REGEX = %r{^https://otel\.collector\.[a-z0-9-]+\.[a-z0-9-]+\.solarwinds\.com(?::\d+)?/v1/(?:logs|metrics|traces)$}
    SWO_OTLP_ENDPOINT_DEFAULT = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    OTEL_SIGNAL_TYPE = %w[TRACES METRICS LOGS].freeze

    def initialize
      @token = nil
    end

    def config_otlp_token_and_endpoint
      matches = ENV['SW_APM_COLLECTOR'].to_s.match(SWO_APM_ENDPOINT_REGEX)

      resolve_get_setting_endpoint(matches)

      service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', SolarWindsAPM::Utils.determine_lambda_env)
      @token = service_key_checker.token unless service_key_checker.token.nil?

      OTEL_SIGNAL_TYPE.each do |data_type|
        config_token(data_type)
        configure_otlp_endpoint(data_type, matches)
      end
    end

    # APM Libraries should only set the bearer token header as a convenience if:
    # The OTEL config for exporter OTLP headers is not already set, i.e. explicitly configured by the end user, AND
    # The OTLP export endpoint is SWO, i.e. host is otel.collector.*.*.solarwinds.com
    def config_token(data_type)
      data_type_upper = data_type.upcase

      return unless @token

      # puts "#{ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"].to_s.match?(SWO_OTLP_SIGNAL_ENDPOINT_REGEX)}"
      # puts "#{ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].to_s.match?(SWO_OTLP_GENERAL_ENDPOINT_REGEX)}"
      if ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_HEADERS"].to_s.empty? && ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"].to_s.match?(SWO_OTLP_SIGNAL_ENDPOINT_REGEX)
        ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_HEADERS"] = "authorization=Bearer #{@token}"
      elsif ENV['OTEL_EXPORTER_OTLP_HEADERS'].to_s.empty? && ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].to_s.match?(SWO_OTLP_GENERAL_ENDPOINT_REGEX)
        ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "authorization=Bearer #{@token}"
      end
    end

    def configure_otlp_endpoint(data_type, matches)
      data_type_upper = data_type.upcase
      data_type_lower = data_type.downcase
      otlp_endpoint_source = if ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"]
                               "#{data_type_lower}_endpoint"
                             elsif ENV['OTEL_EXPORTER_OTLP_ENDPOINT']
                               'general_endpoint'
                             else
                               'no_endpoint'
                             end

      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] otlp_endpoint_source: #{otlp_endpoint_source}" }

      return unless otlp_endpoint_source == 'no_endpoint'

      if matches&.size == 3
        region = matches[1]
        env    = matches[2]
        ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"] = "https://otel.collector.#{region}.#{env}.solarwinds.com:443/v1/#{data_type_lower}"
      else
        ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"] = "https://otel.collector.na-01.cloud.solarwinds.com:443/v1/#{data_type_lower}"
      end
    end

    # only valid value is apm.collector.*.*.solarwinds.com
    # If SW APM config for collector is not set, the fallback: apm.collector.na-01.cloud.solarwinds.com
    def resolve_get_setting_endpoint(matches)
      return if matches&.size == 3

      SolarWindsAPM.logger.warn { "[#{self.class}/#{__method__}] SW_APM_COLLECTOR format invalid: #{ENV.fetch('SW_APM_COLLECTOR', nil)}. Valid formt: apm.collector.*.*.solarwinds.com" }
      ENV['SW_APM_COLLECTOR'] = SWO_APM_ENDPOINT_DEFAULT
    end
  end
end
