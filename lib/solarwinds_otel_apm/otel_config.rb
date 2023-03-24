module SolarWindsOTelAPM
  # OTelConfig module
  # For configure otel component: configurable: propagator, exporter
  #                               non-config: sampler, processor, response_propagator
  # Level of this configuration: SolarWindsOTel::Config -> OboeOption -> SolarWindsOTel::OTelConfig
  module OTelConfig
    @@config           = {}
    @@config_map       = {}
    @@instrumentations = [] # used for use_all/use 
    @@txn_manager      = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new

    def self.resolve_service_name
      @@config[:service_name] = ENV['SERVICE_NAME'] || SolarWindsOTelAPM::Config[:service_name] || ''
    end

    # propagator config is comma separated
    # tracestate propagator is mandatory and at first place
    # propagator setup: must include otel's tracecontext propagator, and the order matters
    # 
    # in this practice, we can choose either allow user set propagator that we support or their customized propagator
    # it is ok to have multiple propagators that is same class, although it's user's responsibility that these won't create strange behavior
    # 
    # With extrac config 
    # SolarWindsOTelAPM::OTelConfig.initialize do |config|
    #   config["OpenTelemetry::Propagators"] = []
    # end
    # 
    # SolarWindsOTelAPM::OTelConfig.initialize do |config|
    #   config["OpenTelemetry::Propagators"] = 'abc'
    # end
    def self.resolve_propagators
      propagators = ENV["SWO_OTEL_PROPAGATOR"] || SolarWindsOTelAPM::Config[:otel_propagator] || 'baggage,solarwinds'
      propagators_list = []
      propagators_list << ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new      # mandatory
      
      if @@config_map['OpenTelemetry::Propagators']
        case @@config_map['OpenTelemetry::Propagators'].class.to_s
        when 'Array'
          @@config_map['OpenTelemetry::Propagators'].each do |propagator|
            propagators_list << propagator if propagator?(propagator)
          end
        when 'String'
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Don't support String. Please provided initialized propagator w/o array."
        when 'Hash'
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Don't support Hash. Please provided initialized propagator w/o array."
        when 'Class'
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Don't support Class. Please provided initialized propagator w/o array."
        when 'Module'
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Don't support Module. Please provided initialized propagator w/o array."
        else
          propagators_list << @@config_map['OpenTelemetry::Propagators'] if propagator?(@@config_map['OpenTelemetry::Propagators'])
        end

        @@config_map.delete('OpenTelemetry::Propagators')
      end

      propagators_list << ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new if propagators.include? 'baggage'
      # solarwinds propagator always in the end
      propagators_list << SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new if propagators.include? 'solarwinds'

      if propagators_list.size == 1
        SolarWindsOTelAPM.logger.warn '[solarwinds_otel_apm/otel_config] Default propagators tracecontext,baggage,solarwinds will be used.'
        propagators_list = [::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new,
                            ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new,
                            SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new]
      end

      @@config[:propagators] = propagators_list
    end

    def self.propagator?(propagator)
      begin
        propagator.methods.include?(:extract) && propagator.methods.include?(:inject) 
      rescue StandardError => e
        SolarWindsOTelAPM.logger.warn "solarwinds_otel_apm/otel_config] Check propagator #{propagator} failed. Error: #{e.message}"
        false
      end
    end

    def self.resolve_span_processor
      @@config[:span_processor] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor.new(@@config[:exporter], @@txn_manager)
    end

    # supported exporter includes: solarwinds, otlp_proto_grpc
    # for additional exporter, please configure it as 
    # SolarWindsOTelAPM::OTelConfig.initialize do |config|
    #   config["OpenTelemetry::Exporter"] = OpenTelemetry::Exporter::OTLP::Exporter.new
    # end
    def self.resolve_exporter

      @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: @@txn_manager)

      return unless @@config_map['OpenTelemetry::Exporter'] && ![Class, Module].include?(@@config_map['OpenTelemetry::Exporter'].class)

      @@config[:exporter] = @@config_map['OpenTelemetry::Exporter']
      SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] The customer provided exporter #{@@config[:exporter]} is used."
      @@config_map.delete_if {|k,_v| k == 'OpenTelemetry::Exporter'}
    end

    def self.resolve_sampler

      resolve_sampler_config
      @@config[:sampler] = 
        ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
          root: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
          remote_parent_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
          remote_parent_not_sampled: SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]))
    end

    def self.resolve_sampler_config
      return unless (ENV["TRIGGER_TRACE"] || SolarWindsOTelAPM::Config[:trigger_trace]) == "enabled"
      
      sampler_config = {}
      sampler_config["trigger_trace"] = "enabled" if (ENV["TRIGGER_TRACE"] || SolarWindsOTelAPM::Config[:trigger_trace]) == "enabled"
      @@config[:sampler_config] = sampler_config
    end

    # 
    # Current strategy is to have the ENV or config to detect the possible configuration for each instrumentation.
    # When initialize, there is no change allowed (resolve_instrumentation_config_map happens before initialize)
    # More fliexable way is to disable loading opentelemetry by default, and then user can load swo-customized configuration (for otel) manually
    # Because reporter initialization is before opentelemetry initialization
    # 
    def self.resolve_instrumentation_config_map
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
    def self.initialize
      yield @@config_map if block_given?

      resolve_service_name
      resolve_propagators
      resolve_sampler
      resolve_exporter
      resolve_span_processor

      print_config if SolarWindsOTelAPM.logger.level.zero?

      if defined?(::OpenTelemetry::SDK::Configurator)
        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = @@config[:service_name]
          c.add_span_processor(@@config[:span_processor])
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
      nil
    end
  end
end