# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # OTLPEndPoint
  class OTLPEndPoint

    SW_ENDPOINT_REGEX = /^apm\.collector\.([a-z0-9-]+)\.cloud\.solarwinds\.com$/
    OTEL_ENDPOINT_REGEX = %r{^https://otel\.collector\.([a-z0-9-]+)\.cloud\.solarwinds\.com:443(?:/.*)?$}
    OTEL_ENDPOINT_LOCAL_REGEX = %r{\Ahttp://0\.0\.0\.0:(4317|4318)\z}
    OTEL_ENDPOINT_LOCAL_REGEX2 = %r{\Ahttp://0\.0\.0\.0:(4317|4318)/v1/(metrics|traces|logs)\z}
    DEFAULT_OTLP_ENDPOINT = 'https://otel.collector.na-01.cloud.solarwinds.com:443'
    DEFAULT_APMPROTO_ENDPOINT = 'apm.collector.na-01.cloud.solarwinds.com'

    def initialize
      @token = nil
      @service_name = nil
      @lambda_env = determine_lambda_env
      @agent_enable = true
      @localhost = false
      determine_if_localhost
    end

    def determine_if_localhost
      @localhost = true if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].to_s.match?(OTEL_ENDPOINT_LOCAL_REGEX)
      @localhost = true if ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'].to_s.match?(OTEL_ENDPOINT_LOCAL_REGEX2)
      @localhost = true if ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'].to_s.match?(OTEL_ENDPOINT_LOCAL_REGEX2)
      @localhost = true if ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'].to_s.match?(OTEL_ENDPOINT_LOCAL_REGEX2)
    end

    def config_otlp_endpoint
      config_service_name
      config_token
      ['TRACES','METRICS','LOGS'].each { |data_type| configure_otlp_endpoint(data_type) }
    end

    def config_service_name
      resource_attributes = ENV['OTEL_RESOURCE_ATTRIBUTES'].to_s.split(',').each_with_object({}) do |resource, hash|
        key, value = resource.split('=')
        hash[key] = value
      end

      unless @lambda_env
        @service_name = ENV['OTEL_SERVICE_NAME'] || resource_attributes['service.name'] || @service_name || 'None'
      else
        @service_name = ENV['OTEL_SERVICE_NAME'] || ENV['AWS_LAMBDA_FUNCTION_NAME'] || resource_attributes['service.name']
      end

      ENV['OTEL_SERVICE_NAME'] = @service_name
    end

    def mask_token(token)
      token = token.to_s
      return '*' * token.length if token.length <= 4

      "#{token[0, 2]}#{'*' * (token.length - 4)}#{token[-2, 2]}"
    end

    def config_token
      agent_enable = true
      return agent_enable if @localhost

      if @lambda_env
        # for case 10 and 11, lambda only care about SW_APM_API_TOKEN, not SW_APM_SERVICE_KEY
        agent_enable = ENV['SW_APM_API_TOKEN'].nil? ? false : true
      else

        if ENV['OTEL_EXPORTER_OTLP_METRICS_HEADERS']
          token_type = 'metrics_token'
        elsif ENV['OTEL_EXPORTER_OTLP_HEADERS']
          token_type = 'general_token'
        elsif ENV['SW_APM_SERVICE_KEY']
          token_type = 'service_key'
        else
          token_type = 'invalid'
        end

        case token_type
        when 'metrics_token' || 'general_token'
          # exporter header is ok, but still need extract it for sampler http get setting
          headers = token_type == 'general_token' ? ENV['OTEL_EXPORTER_OTLP_HEADERS'] : ENV['OTEL_EXPORTER_OTLP_METRICS_HEADERS']
          @token = headers.gsub("authorization=Bearer ", "")
        when 'service_key'
          if valid?(ENV['SW_APM_SERVICE_KEY'])
            @token, @service_name = ENV['SW_APM_SERVICE_KEY'].to_s.split(':')
          else
            SolarWindsAPM.logger.warn { "SW_APM_SERVICE_KEY is invalid: #{mask_token(ENV['SW_APM_SERVICE_KEY'])}" }
          end

          ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "authorization=Bearer #{@token}"
        end

        agent_enable = token_type == 'invalid' ? false : true
      end

      @agent_enable = agent_enable
      agent_enable
    end

    def valid?(service_key)
      # servicekey checker also works on service name, may need to remove that part
      service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      service_key_name = service_key_checker.read_and_validate_service_key
      service_key_name == '' ? false : true
    end

    def determine_lambda_env
      if ENV['LAMBDA_TASK_ROOT'].to_s.empty? && ENV['AWS_LAMBDA_FUNCTION_NAME'].to_s.empty?
        false
      else
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] lambda environment - LAMBDA_TASK_ROOT: #{ENV.fetch('LAMBDA_TASK_ROOT', nil)}; AWS_LAMBDA_FUNCTION_NAME: #{ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)}" }
        true
      end
    end

    # token and endpoint also need to be considered for get settings
    # endpoint is for get settings, populate to OTEL_EXPORTER_OTLP_METRICS_ENDPOINT at the end for otlp related exporter
    # three sources: otlp env variable, sw env variable, sw config file

    # sampler_config = {
    #         collector: "https://#{ENV.fetch('SW_APM_COLLECTOR', 'apm.collector.na-01.cloud.solarwinds.com')}:443",
    #         service: service_key_name[1],
    #         headers: "Bearer #{service_key_name[0]}",
    #         tracing_mode: SolarWindsAPM::Config[:tracing_mode],
    #         trigger_trace_enabled: SolarWindsAPM::Config[:trigger_tracing_mode],
    #         transaction_settings: SolarWindsAPM::Config[:transaction_settings]
    #       }
    def configure_otlp_endpoint(data_type)
      # for staging, our purpose, just use OTEL_EXPORTER_OTLP_METRICS_ENDPOINT directly
      # https://otel.collector.cloud.solarwinds.com:443/v1/traces
      # SW_ENDPOINT_REGEX = /^apm\.collector(?:\.[a-z0-9-]+)?\.cloud\.solarwinds\.com$/

      return unless ['TRACES','METRICS','LOGS'].include?(data_type)

      data_type_upper = data_type.upcase
      data_type = data_type.downcase

      endpoint_type = nil
      if ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"]
        endpoint_type = "#{data_type}_endpoint"
      elsif ENV['OTEL_EXPORTER_OTLP_ENDPOINT']
        endpoint_type = 'general_endpoint'
      elsif ENV['SW_APM_COLLECTOR'].nil? && !@lambda_env
        endpoint_type = 'default_nil'
      elsif ENV['SW_APM_COLLECTOR'].to_s.match?(SW_ENDPOINT_REGEX)
        endpoint_type = 'apm_proto'
      else
        endpoint_type = 'invalid'
      end

      # endpoint = nil
      sampler_collector_endpoint = nil
      case endpoint_type
      when "#{data_type}_endpoint" || 'general_endpoint'
        # no need to worry about metrics endpoint, just need to make sure the collector endpoint is set for getsetting
        endpoint = endpoint_type == 'general_endpoint' ? ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] : ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"]
        
        if endpoint.to_s.match?(OTEL_ENDPOINT_REGEX)
          matches = endpoint.to_s.match(OTEL_ENDPOINT_REGEX)
          region = matches[1]
          sampler_collector_endpoint = DEFAULT_APMPROTO_ENDPOINT.gsub('na-01', region)
          ENV['SW_APM_COLLECTOR'] = sampler_collector_endpoint
        else
          # not the standard otel endpoint, use it directly
          # what to do with collector ?
        end

      when 'default_nil'
        # default_nil => no otlp endpoint or no SW_APM_COLLECTOR, use the default apm proto endpoint
        ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"] = "#{DEFAULT_OTLP_ENDPOINT}/v1/#{data_type}"
        ENV['SW_APM_COLLECTOR'] = DEFAULT_APMPROTO_ENDPOINT

      when 'apm_proto'
        # default     => no otlp endpoint but have SW_APM_COLLECTOR, use the endpoint from SW_APM_COLLECTOR
        # when in testing/staging, we need to set both otlp endpoint and SW_APM_COLLECTOR
        matches = ENV['SW_APM_COLLECTOR'].to_s.match(SW_ENDPOINT_REGEX)
        region = matches[1]
        apmproto_endpoint = DEFAULT_APMPROTO_ENDPOINT.gsub("na-01", region)
        apmproto_endpoint = apmproto_endpoint.gsub("apm", "otel")
        ENV["OTEL_EXPORTER_OTLP_#{data_type_upper}_ENDPOINT"] = "https://#{apmproto_endpoint}:443/v1/#{data_type}"
      end

      # true means setup ok, false meaning setup failed
      # lambda use collector extension to export, so no need have valid endpoint_type
      endpoint_type == 'invalid' && !@lambda_env ? false : true
    end
  end
end
