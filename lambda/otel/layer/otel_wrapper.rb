# frozen_string_literal: true

require 'opentelemetry-metrics-api'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp'
require 'opentelemetry/instrumentation/aws_lambda/handler'

otel_lambda_handler = OpenTelemetry::Instrumentation::AwsLambda::Handler.new
require 'solarwinds_apm'

define_method(:otel_wrapper) do |event:, context:|
  otel_lambda_handler.call_wrapped(event: event, context: context)
end
