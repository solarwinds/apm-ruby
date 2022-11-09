require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# override
require_relative '../configurator.rb'

# customized component
pattern = File.join(File.dirname(__FILE__), 'opentelemetry', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    SolarWindsAPM.logger.error "[solarwinds_otel_apm/loading] Error loading support file '#{f}' : #{e}"
    SolarWindsAPM.logger.debug "[solarwinds_otel_apm/loading] #{e.backtrace.first}"
  end
end

if defined?(OpenTelemetry::SDK::Configurator)
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV['SERVICE_NAME'] || ""
    c.use_all() # enables all instrumentation! or use logic to determine which module to require
  end
end