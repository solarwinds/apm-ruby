# frozen_string_literal: true

require 'opentelemetry-metrics-api'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp'
require 'solarwinds_apm'

def otel_wrapper(event:, context:)
  otel_wrapper = OpenTelemetry::Instrumentation::AwsLambda::Handler.new
  otel_wrapper.call_wrapped(event: event, context: context)
end
