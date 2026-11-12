# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'uri'
require_relative 'service_key_checker'

module SolarWindsAPM
  # OTLPEndPoint
  class OTLPEndPoint
    attr_reader :token, :service_name

    # \A and \z (not ^ and $) so a value containing a newline cannot smuggle a second line past the check.
    # The environment segment is restricted to hostname characters so values such as
    # apm.collector.na-01.foo@evil.example:443/.solarwinds.com are rejected.
    SWO_APM_ENDPOINT_REGEX = /\Aapm\.collector\.([a-z]{2}-\d{2})\.([a-z0-9-]+)\.solarwinds\.com(?::\d+)?\z/
    SWO_APM_ENDPOINT_DEFAULT = 'apm.collector.na-01.cloud.solarwinds.com:443'

    SWO_OTLP_HOST_REGEX = /\Aotel\.collector\.[a-z0-9-]+\.[a-z0-9-]+\.solarwinds\.com\z/
    SWO_OTLP_ENDPOINT_DEFAULT = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    OTEL_SIGNAL_TYPE = %w[TRACES METRICS LOGS].freeze

    def initialize
      @token = nil
      @service_name = nil
    end

    def config_otlp_token_and_endpoint
      matches = ENV['SW_APM_COLLECTOR'].to_s.match(SWO_APM_ENDPOINT_REGEX)

      resolve_get_setting_endpoint(matches)

      service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', SolarWindsAPM::Utils.determine_lambda)
      @token = service_key_checker.token
      @service_name = service_key_checker.service_name

      # Resolve the endpoint first so the token decision is made against the endpoint the exporter will actually use.
      OTEL_SIGNAL_TYPE.each do |data_type|
        configure_otlp_endpoint(data_type, matches)
        config_token(data_type)
      end
    end

    # APM Libraries should only set the bearer token header as a convenience if:
    # The OTEL config for exporter OTLP headers is not already set, i.e. explicitly configured by the end user, AND
    # The OTLP export endpoint is SWO, i.e. host is otel.collector.*.*.solarwinds.com
    #
    # The header is always set on the signal-specific variable (never on the general OTEL_EXPORTER_OTLP_HEADERS),
    # so that it cannot be inherited by another signal that exports to a non-SWO endpoint.
    # Users exporting to their own collector that forwards to SWO must set OTEL_EXPORTER_OTLP_HEADERS
    # (or the signal-specific variant) themselves.
    def config_token(data_type)
      data_type_upper = data_type.upcase
      signal_headers_env = "OTEL_EXPORTER_OTLP_#{data_type_upper}_HEADERS"

      return unless @token
      return unless ENV[signal_headers_env].to_s.empty? && ENV['OTEL_EXPORTER_OTLP_HEADERS'].to_s.empty?

      endpoint = effective_endpoint(data_type_upper)
      if swo_otlp_endpoint?(endpoint)
        ENV[signal_headers_env] = "authorization=Bearer #{@token}"
      else
        SolarWindsAPM.logger.info do
          "[#{self.class}/#{__method__}] #{data_type_upper} OTLP endpoint #{sanitize_endpoint(endpoint)} is not a SolarWinds Observability endpoint; " \
            'SW_APM_SERVICE_KEY will not be sent as authorization header. If this collector forwards to SolarWinds Observability, ' \
            "set #{signal_headers_env} or OTEL_EXPORTER_OTLP_HEADERS explicitly."
        end
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

    # Same precedence as the OpenTelemetry OTLP exporters: signal-specific endpoint, then the general endpoint.
    def effective_endpoint(data_type_upper)
      ENV.fetch("OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT", nil) || ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)
    end

    # Parse the URL rather than pattern-matching the raw string, so userinfo, path or
    # newline tricks cannot make a non-SWO host look like a SWO one.
    def swo_otlp_endpoint?(endpoint)
      return false if endpoint.to_s.empty?

      uri = URI.parse(endpoint.to_s.strip)
      uri.scheme == 'https' && uri.userinfo.nil? && uri.host.to_s.downcase.match?(SWO_OTLP_HOST_REGEX)
    rescue URI::Error
      false
    end

    # Only scheme, host and port are logged, never userinfo or query that may carry credentials.
    def sanitize_endpoint(endpoint)
      uri = URI.parse(endpoint.to_s.strip)
      return '<unparseable>' if uri.host.nil?

      "#{uri.scheme}://#{uri.host}:#{uri.port}"
    rescue URI::Error
      '<unparseable>'
    end

    # only valid value is apm.collector.*.*.solarwinds.com
    # If SW APM config for collector is not set, the fallback: apm.collector.na-01.cloud.solarwinds.com
    def resolve_get_setting_endpoint(matches)
      return if matches&.size == 3

      unless ENV['SW_APM_COLLECTOR'].to_s.empty?
        SolarWindsAPM.logger.warn do
          "[#{self.class}/#{__method__}] SW_APM_COLLECTOR format invalid: #{ENV.fetch('SW_APM_COLLECTOR', nil)}. Valid format: apm.collector.*.*.solarwinds.com"
        end
      end
      ENV['SW_APM_COLLECTOR'] = SWO_APM_ENDPOINT_DEFAULT
    end
  end
end
