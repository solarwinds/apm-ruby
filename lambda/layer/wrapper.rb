require 'solarwinds_apm'
require 'opentelemetry/instrumentation/aws_lambda'

::OpenTelemetry::Instrumentation.registry.register('OpenTelemetry::Instrumentation::AwsLambda')
::OpenTelemetry::Instrumentation.registry.install(['OpenTelemetry::Instrumentation::AwsLambda'])

def otel_wrapper(event:, context:)
  otel_wrapper = OpenTelemetry::Instrumentation::AwsLambda::Handler.new()
  otel_wrapper.call_wrapped(event: event, context: context)
end
