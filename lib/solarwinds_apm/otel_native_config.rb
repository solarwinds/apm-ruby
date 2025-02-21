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

module SolarWindsAPM
  # OTelLambdaConfig module
  module OTelNativeConfig

    @@config           = {}
    @@config_map       = {}
    @@agent_enabled    = true

    def self.initialize
      return unless defined?(::OpenTelemetry::SDK::Configurator)

      ENV['OTEL_TRACES_EXPORTER'] = ENV['OTEL_TRACES_EXPORTER'].to_s.split(',').tap { |e| e << 'otlp' unless e.include?('otlp') }.join(',')
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = "sw.apm.version=#{SolarWindsAPM::Version::STRING},sw.data.module=apm,service.name=#{ENV.fetch('OTEL_SERVICE_NAME', nil)}," + ENV['OTEL_RESOURCE_ATTRIBUTES'].to_s

      resolve_solarwinds_propagator
      resolve_response_propagator

      # for dbo, traceparent injection as comments
      require_relative 'patch/tag_sql_patch' if SolarWindsAPM::Config[:tag_sql]

      ::OpenTelemetry::SDK.configure { |c| c.use_all(@@config_map) }

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new)

      # register metrics_exporter to meter_provider
      ::OpenTelemetry.meter_provider.add_metric_reader(::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new)

      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(@@config[:propagators])

      # append our processors
      ::OpenTelemetry.tracer_provider.add_span_processor(SolarWindsAPM::OpenTelemetry::OTLPProcessor.new)

      service_key_name = ENV['SW_APM_SERVICE_KEY'].to_s.split(":")

      # no need to send init msg for otlp proto
      sampler_config = {
        :collector => "https://#{ENV.fetch('SW_APM_COLLECTOR', 'apm.collector.cloud.solarwinds.com')}:443",
        :service => service_key_name[1],
        :headers => "Bearer #{service_key_name[0]}",
        :tracing_mode => SolarWindsAPM::Config[:tracing_mode],
        :trigger_trace_enabled => SolarWindsAPM::Config[:trigger_tracing_mode],
        :transaction_settings => SolarWindsAPM::Config[:transaction_settings]
      }

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
        root: HttpSampler.new(sampler_config)
      )

      nil
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

    def self.resolve_solarwinds_propagator
      @@config[:propagators] = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    end
  end
end
