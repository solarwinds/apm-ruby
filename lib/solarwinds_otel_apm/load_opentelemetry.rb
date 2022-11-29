require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# customized component
pattern = File.join(File.dirname(__FILE__), 'opentelemetry', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    SolarWindsAPM.logger.error "[solarwinds_otel_apm/loading] Error loading opentelemetry file '#{f}' : #{e}"
    SolarWindsAPM.logger.debug "[solarwinds_otel_apm/loading] #{e.backtrace.first}"
  end
end

if defined?(OpenTelemetry::SDK::Configurator)
  OpenTelemetry::SDK.configure do |c|
    
    c.service_name = ENV['SERVICE_NAME'] || ""
    
    txn_name_manager = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new
    c.add_span_processor(SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor.new(
                                  Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter").new(apm_txname_manager: txn_name_manager), 
                                  txn_name_manager,
                                  true))

    #* we have added the propagators in override
    #* propagators use this way to add data to span: setter.set(carrier, B3_TRACE_ID_KEY, span_context.hex_trace_id)
    c.propagators = [SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new]

    c.use_all() # enables all instrumentation! or use logic to determine which module to require
  end
end


# configure sampler afterwards (sampler is a standalone beast)
sampler_config = Hash.new
sampler_config["trigger_trace"] =  "enabled"
OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config))


# configure propogator afterwards
# this will overwrite the configurator.configure_propagation method
# if we want to have multiple propagators, then we can use this for easy customization
# OpenTelemetry.propagation = Context::Propagation::CompositeTextMapPropagator.compose_propagators([Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry").solarwinds_propogator])
