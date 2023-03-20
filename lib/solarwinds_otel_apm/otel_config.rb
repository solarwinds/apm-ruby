module SolarWindsOTelAPM
  # OTelConfig module
  # For configure otel component: configurable: propagator, exporter
  #                               non-config: sampler, processor, response_propagator
  # Level of this configuration: SolarWindsOTel::Config -> OboeOption -> SolarWindsOTel::OTelConfig
  module OTelConfig
    @@config = {}
    @@config_map = {}
    @@instrumentations = [] # used for use_all/use

    # propagator config is comma separated
    # propagator setup: must include otel's tracecontext propagator, and the order matters
    def self.resolve_propagators
      propagators = ENV["SWO_OTEL_PROPAGATOR"] || SolarWindsOTelAPM::Config[:otel_propagator] || 'tracecontext,baggage,solarwinds'
      propagators_list = []
      splited_propagators = propagators.split(",")
      splited_propagators.each do |propagator|
        case propagator
        when 'tracecontext'
          propagators_list << ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new
        when 'baggage'
          propagators_list << ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new
        end
      end

      # solarwinds propagator always in the end
      propagators_list << SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new if splited_propagators.include? 'solarwinds'

      if propagators_list.size == 0
        propagators_list = [::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new,
                            ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new,
                            SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new]
      end

      @@config[:propagators] = propagators_list
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

    def self.resolve_span_processor
      @@config[:span_processor] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
    end

    def self.resolve_service_name
      @@config[:service_name] = ENV['SERVICE_NAME'] || SolarWindsOTelAPM::Config[:service_name] || ''
    end

    def self.resolve_sampler
      resolve_sampler_config
      @@config[:sampler] = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
                                root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                                remote_parent_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
                                remote_parent_not_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config])
                              )
    end

    def self.resolve_sampler_config
      return unless (ENV["TRIGGER_TRACE"] || SolarWindsOTelAPM::Config[:trigger_trace]) == "enabled"

      @@config[:sampler_config] = {"trigger_trace" => "enabled"}
    end

    # 
    # Response propagator that inside Rack instrumentation is default swo 
    def self.resolve_response_propagator
      response_propagators_list = [SolarWindsOTelAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new]
      if @@config_map["OpenTelemetry::Instrumentation::Rack"]
        @@config_map["OpenTelemetry::Instrumentation::Rack"][:response_propagators] = response_propagators_list
      else
        @@config_map["OpenTelemetry::Instrumentation::Rack"] = {response_propagators: response_propagators_list}
      end
    end

    # this may not even needed if use_all is allowed
    # 
    def self.resolve_instrumentation_library
      # determine which gem is loaded and load the corresponding instrumentation
      @@instrumentations << 'OpenTelemetry::Instrumentation::Rack' if defined?(Rack)
      
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.print_config
      @@config.each do |config, value|
        SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Config[:#{config}] = #{value}"
      end
      @@config_map.each do |config, value|
        SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Config.config_map #{config} = #{value}"
      end
    end

    # 
    # Allow reinitialize after set new value to SolarWindsOTelAPM::Config[:key]=value
    # 
    # Usage:
    # Without extra config for instrumentation:
    #     SolarWindsOTelAPM::OTelConfig.initialize 
    # 
    # With extrac config 
    # SolarWindsOTelAPM::OTelConfig.initialize do |config|
    #   config["OpenTelemetry::Instrumentation::Rack"] = {"a" => "b"}
    #   config["OpenTelemetry::Instrumentation::Dalli"] = {"a" => "b"}
    # end
    #
    #
    def self.initialize
      resolve_service_name
      resolve_propagators
      resolve_sampler
      resolve_span_processor
      resolve_exporter

      yield @@config_map if block_given?

      resolve_response_propagator
      txn_name_manager     = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new

      if defined?(::OpenTelemetry::SDK::Configurator)
        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = @@config[:service_name]
          c.add_span_processor(@@config[:span_processor].new(@@config[:exporter].new(apm_txname_manager: txn_name_manager),txn_name_manager))
          c.propagators = @@config[:propagators]
          c.use_all(@@config_map)

          # use separately
          # @@instrumentations.each do |instrumentation|
          #   c.use instrumentation, @@config_map[instrumentation.class.to_s]
          # end
        end
      end

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = @@config[:sampler]
    end
  end
end