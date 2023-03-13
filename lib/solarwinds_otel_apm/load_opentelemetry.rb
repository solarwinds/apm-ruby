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


module SolarWindsOTelAPM
  module OTelConfig

    @@config = {}
    @@config_map = {}
    @@instrumentations = [] # used for use_all/use 

    def self.resolve_service_name
      @@config[:service_name] = ENV['SERVICE_NAME'] || SolarWindsOTelAPM::Config[:service_name] || ''

    end

    # propagator config is comma separated
    # propagator setup: must include otel's tracecontext propagator
    def self.resolve_propagators
      propagators = ENV["SWO_OTEL_PROPAGATOR"] || SolarWindsOTelAPM::Config[:otel_propagator] || 'tracecontext,baggage,solarwinds'
      propagators_list = Array.new
      propagators.split(",").each do |propagator|
        case propagator
        when 'solarwinds'
          propagators_list << SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
        when 'tracecontext'
          propagators_list << ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new
        when 'baggage'
          propagators_list << ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new
        end
      end

      @@config[:propagators] = propagators_list

    end

    def self.resolve_span_processor
      span_processor = ENV["SWO_OTEL_PROCESSOR"] || SolarWindsOTelAPM::Config[:otel_processor] || ''
      case span_processor
      when 'solarwinds'
        @@config[:span_processor] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
      else
        @@config[:span_processor] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
        SolarWindsOTelAPM::Logger.warn "[solarwinds_otel_apm/otel_config] The default exporter is used"
      end

    end

    def self.resolve_exporter
      exporter = ENV["SWO_OTEL_EXPORTER"] || SolarWindsOTelAPM::Config[:otel_exporter] || ''

      case exporter
      when 'solarwinds'
        @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
      else
        @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
        SolarWindsOTelAPM::Logger.warn "[solarwinds_otel_apm/otel_config] The default exporter is used"
      end

    end

    def self.resolve_sampler

      resolve_sampler_config

      sampler = ENV["SWO_OTEL_SAMPLER"] || SolarWindsOTelAPM::Config[:otel_sampler] || ''
      case sampler
      when 'solarwinds'
        @@config[:sampler] = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
                      root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                      remote_parent_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                      remote_parent_not_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]))
      else

        @@config[:sampler] = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
                      root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                      remote_parent_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                      remote_parent_not_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]))
        SolarWindsOTelAPM::Logger.warn "[solarwinds_otel_apm/otel_config] The default sampler is used"
      end

    end

    def self.resolve_sampler_config

      sampler_config = Hash.new
      sampler_config["trigger_trace"] = "enabled" if (ENV["TRIGGER_TRACE"] || SolarWindsOTelAPM::Config[:trigger_trace]) == "enabled"
      @@config[:sampler_config] = sampler_config

    end

    def self.resolve_instrumentation_config_map
      response_propagators = ENV["SWO_OTEL_RESPONSE_PROPAGATOR"] || SolarWindsOTelAPM::Config[:otel_response_propagator] || 'solarwinds'
      response_propagators_list = Array.new
      response_propagators.split(",").each do |res|
        case res
        when 'solarwinds'
          response_propagators_list << SolarWindsOTelAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
        else
          response_propagators_list << SolarWindsOTelAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
          SolarWindsOTelAPM::Logger.warn "[solarwinds_otel_apm/otel_config] The default exporter is used"
        end
      end

      @@config_map["OpenTelemetry::Instrumentation::Rack"] = { response_propagators: response_propagators_list}

    end

    # this may not even needed if use_all is allowed
    def self.resolve_instrumentation_library
      # determine which gem is loaded and load the corresponding instrumentation
      if defined?(Rack)
        @@instrumentations << 'OpenTelemetry::Instrumentation::Rack'
      end

    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.print_config
      @@config.each do |config|
        SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Config[:#{config}] = #{@@config[config]}"
      end
      @@config_map.each do |config|
        SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Config.config_map #{config} = #{@@config_map[config]}"
      end
    end

    # 
    # Allow reinitialize after set new value to SolarWindsOTelAPM::Config[:key]=value
    #
    def self.initialize

      resolve_propagators
      resolve_sampler
      resolve_exporter
      resolve_span_processor
      resolve_service_name
      resolve_instrumentation_config_map

      txn_name_manager = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new

      if defined?(::OpenTelemetry::SDK::Configurator)
        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = @@config[:service_name]
          c.add_span_processor(@@config[:span_processor].new(@@config[:exporter].new(apm_txname_manager: txn_name_manager),txn_name_manager))
          c.propagators = @@config[:propagators]
          c.use_all(@@config_map)

          # use separately
          # @@instrumentations.each do |instrumentation|
          #   c.use instrumentation
          # end
        end
      end

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = @@config[:sampler]

    end
  end
end

SolarWindsOTelAPM::OTelConfig.initialize


