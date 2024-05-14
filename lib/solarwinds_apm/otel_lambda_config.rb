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

      ENV['OTEL_TRACES_EXPORTER'] = 'none' if ENV['OTEL_TRACES_EXPORTER'].to_s.empty?

      ::OpenTelemetry::SDK.configure do |c|
        c.resource = { 'sw.apm.version' => SolarWindsAPM::Version::STRING,
                       'sw.data.module' => 'apm',
                       'service.name' => ENV['OTEL_SERVICE_NAME'] || ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil) }
        c.use 'OpenTelemetry::Instrumentation::AwsLambda'
      end

      # meter_name is static for swo services
      meters = {
        'sw.apm.sampling.metrics' => ::OpenTelemetry.meter_provider.meter('sw.apm.sampling.metrics'),
        'sw.apm.request.metrics' => ::OpenTelemetry.meter_provider.meter('sw.apm.request.metrics')
      }

      txn_manager          = SolarWindsAPM::TxnNameManager.new
      otlp_metric_exporter = ::OpenTelemetry::Exporter::OTLP::MetricsExporter.new
      otlp_span_exporter   = ::OpenTelemetry::Exporter::OTLP::Exporter.new
      otlp_span_processor  = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(meters, otlp_span_exporter, txn_manager)

      # append our propagators
      solarwinds_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(solarwinds_propagator)

      # register metrics_exporter to meter_provider
      ::OpenTelemetry.meter_provider.add_metric_reader(otlp_metric_exporter)

      # append our processors (with our exporter)
      ::OpenTelemetry.tracer_provider.add_span_processor(otlp_span_processor)

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
        root: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new,
        remote_parent_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new,
        remote_parent_not_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new
      )

      SolarWindsAPM.logger.warn do
        "[#{name}/#{__method__}] SolarWindsAPM lambda configuration initialized \
        \nOpenTelemetry.tracer_provider: #{::OpenTelemetry.tracer_provider.inspect}"
      end

      nil
    end
  end
end
