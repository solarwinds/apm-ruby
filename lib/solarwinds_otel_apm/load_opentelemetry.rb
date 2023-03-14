require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# customized component
pattern = File.join(File.dirname(__FILE__), 'opentelemetry', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    SolarWindsOTelAPM.logger.error "[solarwinds_otel_apm/loading] Error loading opentelemetry file '#{f}' : #{e}"
    SolarWindsOTelAPM.logger.debug "[solarwinds_otel_apm/loading] #{e.backtrace.first}"
  end
end
