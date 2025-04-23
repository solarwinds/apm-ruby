# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'solarwinds_apm/constants'
require 'solarwinds_apm/api'
require 'solarwinds_apm/support'
require 'solarwinds_apm/opentelemetry'
require 'solarwinds_apm/sampling'
require 'solarwinds_apm/patch'

module SolarWindsAPM
  # OTelNativeConfig module
  module OTelNativeConfig
    @@config           = {}
    @@config_map       = {}
    @@agent_enabled    = false

    def self.initialize
      return unless defined?(::OpenTelemetry::SDK::Configurator)

      ENV['OTEL_TRACES_EXPORTER'] = ENV['OTEL_TRACES_EXPORTER'].to_s.split(',').tap { |e| e << 'otlp' unless e.include?('otlp') }.join(',')

      # add response propagator to rack instrumentation
      resolve_response_propagator

      # dbo: traceparent injection as sql comments
      require_relative 'patch/tag_sql_patch' if SolarWindsAPM::Config[:tag_sql]

      # endpoint and service_key
      otlp_endpoint = SolarWindsAPM::OTLPEndPoint.new
      otlp_endpoint.config_otlp_token_and_endpoint
      return if otlp_endpoint.token.nil?

      ENV['OTEL_RESOURCE_ATTRIBUTES'] = "sw.apm.version=#{SolarWindsAPM::Version::STRING},sw.data.module=apm,service.name=#{ENV.fetch('OTEL_SERVICE_NAME', nil)}," + ENV['OTEL_RESOURCE_ATTRIBUTES'].to_s

      # resource attributes
      mandatory_resource = SolarWindsAPM::ResourceDetector.detect
      additional_attributes = @@config_map['resource_attributes']
      if additional_attributes
        @@config_map.delete('resource_attributes')
        if additional_attributes.instance_of?(::OpenTelemetry::SDK::Resources::Resource)
          final_attributes = mandatory_resource.merge(additional_attributes)
        elsif additional_attributes.instance_of?(Hash)
          final_attributes = mandatory_resource.merge(::OpenTelemetry::SDK::Resources::Resource.create(additional_attributes))
        end
      else
        final_attributes = mandatory_resource.merge({})
      end

      # log level
      if ENV['OTEL_LOG_LEVEL'].to_s.empty?
        log_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
        ENV['OTEL_LOG_LEVEL'] = SolarWindsAPM::Config::SW_LOG_LEVEL_MAPPING.dig(log_level, :otel)
      end

      puts "ENV['OTEL_EXPORTER_OTLP_HEADERS']: #{ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)}"
      puts "ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT']: #{ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)}"
      puts "ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']: #{ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)}"

      ::OpenTelemetry::SDK.configure do |c|
        c.resource = final_attributes
        c.use_all(@@config_map)
      end

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new)

      # add sw metrics processors (only record respone_time)
      txn_manager = TxnNameManager.new
      otlp_processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(txn_manager)

      @@config[:metrics_processor] = otlp_processor
      ::OpenTelemetry.tracer_provider.add_span_processor(otlp_processor)

      # get_setting_endpoint = ENV.fetch('SW_APM_COLLECTOR', 'apm.collector.cloud.solarwinds.com:443')
      # if get_setting_endpoint.include?()

      # collector, service and headers are used for http sampler get settings
      sampler_config = {
        collector: "https://#{ENV.fetch('SW_APM_COLLECTOR', 'apm.collector.cloud.solarwinds.com:443')}",
        service: otlp_endpoint.service_name,
        headers: "Bearer #{otlp_endpoint.token}",
        tracing_mode: SolarWindsAPM::Config[:tracing_mode],
        trigger_trace_enabled: SolarWindsAPM::Config[:trigger_tracing_mode],
        transaction_settings: SolarWindsAPM::Config[:transaction_settings]
      }

      sampler = SolarWindsAPM::Utils.determine_lambda ? JsonSampler.new(sampler_config) : HttpSampler.new(sampler_config)

      ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
        root: sampler,
        remote_parent_sampled: sampler,
        remote_parent_not_sampled: sampler
      )

      @@agent_enabled = true

      nil
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.agent_enabled
      @@agent_enabled
    end

    def self.resolve_response_propagator
      response_propagator  = SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
      rack_setting         = @@config_map['OpenTelemetry::Instrumentation::Rack']

      if rack_setting
        if rack_setting[:response_propagators].instance_of?(Array)
          rack_setting[:response_propagators].append(response_propagator)
        elsif rack_setting[:response_propagators].nil?
          rack_setting[:response_propagators] = [response_propagator]
        else
          SolarWindsAPM.logger.warn do
            "[#{name}/#{__method__}] Rack response propagator resolve failed. Provided type #{rack_setting[:response_propagators].class}, please provide Array e.g. [#{rack_setting[:response_propagators]}]"
          end
        end
      else
        @@config_map['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: [response_propagator] }
      end
    end

    #
    # Allow initialize after set new value to SolarWindsAPM::Config[:key]=value
    #
    # Usage:
    #
    # Default using the use_all to load all instrumentation
    # But with specific instrumentation disabled, use {:enabled: false} in config
    # SolarWindsAPM::OTelNativeConfig.initialize_with_config do |config|
    #   config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
    #   config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
    # end
    #
    def self.initialize_with_config
      unless block_given?
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] Block not given while doing in-code configuration. Agent disabled."
        end
        return
      end

      yield @@config_map

      if @@config_map.empty?
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] No configuration given for in-code configuration. Agent disabled."
        end
        return
      end

      initialize
    end
  end
end
