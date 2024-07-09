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

module SolarWindsAPM
  # OTelLambdaConfig module
  module OTelLambdaConfig
    def self.initialize
      return unless defined?(::OpenTelemetry::SDK::Configurator)

      if ENV['OTEL_TRACES_EXPORTER'].to_s.empty?
        ENV['OTEL_TRACES_EXPORTER'] = 'otlp'
      elsif !ENV['OTEL_TRACES_EXPORTER'].include? 'otlp'
        ENV['OTEL_TRACES_EXPORTER'] += ',otlp'
      end

      ENV['OTEL_RESOURCE_ATTRIBUTES'] = "sw.apm.version=#{SolarWindsAPM::Version::STRING},sw.data.module=apm,service.name=#{ENV['OTEL_SERVICE_NAME'] || ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)}," + ENV['OTEL_RESOURCE_ATTRIBUTES'].to_s
      ::OpenTelemetry::SDK.configure(&:use_all)

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new)

      # register metrics_exporter to meter_provider
      ::OpenTelemetry.meter_provider.add_metric_reader(::OpenTelemetry::Exporter::OTLP::MetricsExporter.new)

      # append our processors
      ::OpenTelemetry.tracer_provider.add_span_processor(SolarWindsAPM::OpenTelemetry::OTLPProcessor.new)

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
        root: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new,
        remote_parent_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new,
        remote_parent_not_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new
      )

      SolarWindsAPM.logger.info do
        "[#{name}/#{__method__}] SolarWindsAPM lambda configuration initialized \
        \n                                               Installed instrumentation: #{::OpenTelemetry.tracer_provider.instance_variable_get(:@registry).keys} \
        \n                                               SpanProcessor: #{::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors).map(&:class)} \
        \n                                               Sampler: #{::OpenTelemetry.tracer_provider.instance_variable_get(:@sampler).inspect} \
        \n                                               Resource: #{::OpenTelemetry.tracer_provider.instance_variable_get(:@resource).inspect}"
      end

      nil
    end
  end
end
