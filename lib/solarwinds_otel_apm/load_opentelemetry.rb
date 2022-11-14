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
    
    # if needed, we can add span_processor here because configure will be called at last 
    # span_processor has to have exporter
    # because: processors = @span_processors.empty? ? wrapped_exporters_from_env.compact : @span_processors
    # it's either from wrapped_exporters_from_env (also return processor(exporter)) or processors
    # this config is only useful when you want to configure the processor as well
    c.add_span_processor(SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor.new(Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter").new)) 
    
    # we have added the propagators in override
    # propagators use this way to add data to span: setter.set(carrier, B3_TRACE_ID_KEY, span_context.hex_trace_id)
    c.propagators = [OpenTelemetry::Propagator::XRay::TextMapPropagator.new] 

    c.use_all() # enables all instrumentation! or use logic to determine which module to require
  end
end

# configure sampler afterwards (sampler is a standalone beast)
sampler_config = {}
OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::Samplers.parent_based(root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config))

# configure propogator afterwards
# this will overwrite the configurator.configure_propagation method
# if we want to have multiple propagators, then we can use this for easy customization
OpenTelemetry.propagation = Context::Propagation::CompositeTextMapPropagator.compose_propagators([Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry").solarwinds_propogator])
