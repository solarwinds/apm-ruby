# frozen_string_literal: true

require 'opentelemetry-metrics-api'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp'
# We need to load the function code's dependencies, and _before_ any dependencies might
# be initialized outside of the function handler, bootstrap instrumentation. This allows
# instrumentation targets to be present, and accommodates instrumentations like AWS SDK
# that add plugins on client initialization (vs. prepending methods). 
def preload_libraries
  default_task_location = '/var/task'

  handler_file = ENV.values_at('ORIG_HANDLER', '_HANDLER').compact.first&.split('.')&.first

  unless handler_file && File.exist?("#{default_task_location}/#{handler_file}.rb")
    OpenTelemetry.logger.warn { 'Could not find the original handler file to preload libraries.' }
    return
  end

  libraries = File.read("#{default_task_location}/#{handler_file}.rb")
                  .scan(/^\s*require\s+['"]([^'"]+)['"]/)
                  .flatten

  libraries.each do |lib|
    require lib
  rescue StandardError => e
    OpenTelemetry.logger.warn { "Could not load library #{lib}: #{e.message}" }
  end
end

preload_libraries

require 'opentelemetry/instrumentation/aws_sdk/handler'
require 'opentelemetry/instrumentation/aws_sdk/services'

def loaded_constants
  services = Aws.constants & OpenTelemetry::Instrumentation::AwsSdk::SERVICES.map(&:to_sym)

  services.each_with_object([]) do |service, constants|
    next if Aws.autoload?(service)

    begin
      constants << Aws.const_get(service, false).const_get(:Client, false)
    rescue StandardError => e
      OpenTelemetry.logger.warn { "Constant could not be loaded: #{e.message}" }
    end
  end
end

Seahorse::Client::Base.add_plugin(OpenTelemetry::Instrumentation::AwsSdk::Plugin) if defined?(Seahorse::Client::Base)
loaded_constants.each { |klass| klass.add_plugin(OpenTelemetry::Instrumentation::AwsSdk::Plugin) }

require 'solarwinds_apm'

def otel_wrapper(event:, context:)
  otel_wrapper = OpenTelemetry::Instrumentation::AwsLambda::Handler.new
  otel_wrapper.call_wrapped(event: event, context: context)
end
