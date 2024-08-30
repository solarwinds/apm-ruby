# frozen_string_literal: true

require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp'
require 'opentelemetry-exporter-otlp-metrics'

# We need to load the function code's dependencies, and _before_ any dependencies might
# be initialized outside of the function handler, bootstrap instrumentation. This allows
# instrumentation targets to be present, and accommodates instrumentations like AWS SDK
# that add plugins on client initialization (vs. prepending methods).
def preload_function_dependencies
  default_task_location = '/var/task'

  handler_file = ENV.values_at('ORIG_HANDLER', '_HANDLER').compact.first&.split('.')&.first

  unless handler_file && File.exist?("#{default_task_location}/#{handler_file}.rb")
    OpenTelemetry.logger.warn { 'Could not find the original handler file to preload libraries.' }
    return nil
  end

  libraries = File.read("#{default_task_location}/#{handler_file}.rb")
                  .scan(/^\s*require\s+['"]([^'"]+)['"]/)
                  .flatten

  libraries.each do |lib|
    require lib
  rescue StandardError => e
    OpenTelemetry.logger.warn { "Could not load library #{lib}: #{e.message}" }
  end
  handler_file
end

if ENV['SW_APM_LAMBDA_PRELOAD_DEPS'].to_s.downcase == 'false'
  OpenTelemetry.logger.warn { "SW_APM_LAMBDA_PRELOAD_DEPS set to #{ENV.fetch('SW_APM_LAMBDA_PRELOAD_DEPS', nil)}. No libraries will be preloaded." }
else

  handler_file = preload_function_dependencies

  OpenTelemetry.logger.info { "Libraries in #{handler_file} will be preloaded." } if handler_file

  require 'opentelemetry-registry'
  require 'opentelemetry-instrumentation-all'

  OpenTelemetry::Instrumentation.registry.install_all
end

require 'solarwinds_apm'

def otel_wrapper(event:, context:)
  otel_wrapper = OpenTelemetry::Instrumentation::AwsLambda::Handler.new
  otel_wrapper.call_wrapped(event: event, context: context)
end
