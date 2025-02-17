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
    def self.initialize
      return unless defined?(::OpenTelemetry::SDK::Configurator)

      ENV['OTEL_TRACES_EXPORTER'] = ENV['OTEL_TRACES_EXPORTER'].to_s.split(',').tap { |e| e << 'otlp' unless e.include?('otlp') }.join(',')
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = "sw.apm.version=#{SolarWindsAPM::Version::STRING},sw.data.module=apm,service.name=#{ENV.fetch('OTEL_SERVICE_NAME', nil)}," + ENV['OTEL_RESOURCE_ATTRIBUTES'].to_s

      ::OpenTelemetry::SDK.configure(&:use_all)

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new)

      # register metrics_exporter to meter_provider
      ::OpenTelemetry.meter_provider.add_metric_reader(::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new)

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
  end
end
