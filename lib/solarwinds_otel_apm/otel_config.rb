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
    @@agent_enabled    = true

    def self.resolve_service_name
      @@config[:service_name] = ENV['OTEL_SERVICE_NAME'] || SolarWindsOTelAPM::Config[:service_name] || ''
    end



    def self.disable_agent
      if @@agent_enabled  # only show the msg once
        @@agent_enabled = false
        SolarWindsOTelAPM.logger.warn '[solarwinds_otel_apm/otel_config] Agent disabled. No Trace exported.'
      end
    end

    def self.validate_propagator
      propagators = @@config_map['OpenTelemetry::Propagators']
      if propagators
        propagator_type  = propagators.class.to_s 
        if propagator_type != 'Array'
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Don't support #{propagator_type}. Please provided initialized propagator with array."
          disable_agent
        else
          propagator_types = []
          propagators.each do |propagator|
            if propagator?(propagator)
              propagator_types << propagator.class.to_s
            else
              SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] #{propagator} is not valid propagator."
              disable_agent
              break
            end
          end

          if (['OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator', 'SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator'] - propagator_types).empty?
            unless correct_order?(propagators.map{|pro| pro.class})
              SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] The order of propagators is incorrect. tracecontext need to be in front of solarwinds"
              disable_agent
            end
          else

            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Missing tracecontext or solarwinds propagator."
            disable_agent
          end
        end
      else
        propagator = ENV["OTEL_PROPAGATORS"] || SolarWindsOTelAPM::Config[:otel_propagator] || 'tracecontext,baggage,solarwinds'
        propagators = propagator.split(',')

        if (['tracecontext','solarwinds'] - propagators).empty?
          unless correct_order?(propagators)
            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] The order of propagators is incorrect. tracecontext need to be in front of solarwinds"
            disable_agent
          end
        else
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Missing tracecontext or solarwinds propagator."
          disable_agent
        end

        propagators.each do |propagator|
          case propagator
          when 'tracecontext', 'baggage', 'solarwinds'
            next
          else
            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Propagator #{propagator} is not supported. \n
                                                                             Currently supported exporter include: tracecontext, baggge, solarwinds.\n
                                                                             Trace disabled."
            disable_agent
          end
        end

      end
    end

    def self.validate_exporter
      exporter = @@config_map['OpenTelemetry::Exporter']

      if exporter
        unless exporter?(exporter)
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Exporter #{exporter} is not valid"
          disable_agent
        end

        if [Class, Module].include?(exporter.class)
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Please initialize the exporter when you supply them in configuration."
          disable_agent
        end

      else
        exporter = ENV["OTEL_TRACES_EXPORTER"] || SolarWindsOTelAPM::Config[:otel_exporter] || 'solarwinds'
        case exporter
        when 'solarwinds'
          @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: @@txn_manager)
        else
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] Exporter #{exporter} is not supported. \n
                                                                           Currently supported exporter include: solarwinds.\n
                                                                           Trace disabled."                                                          
          disable_agent
        end
      end
    end

    #
    #
    #
    def self.resolve_propagators
      propagators = []
      propagator = @@config_map['OpenTelemetry::Propagators']
      if propagator
        propagator.each do |propagator|
          propagators << propagator
        end

        @@config_map.delete('OpenTelemetry::Propagators')
      else
        otel_propagator = ENV["OTEL_PROPAGATORS"] || SolarWindsOTelAPM::Config[:otel_propagator] || 'tracecontext,baggage,solarwinds'

        otel_propagator.split(',').each do |propagator|
          case propagator
          when 'tracecontext'
            propagators << ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new
          when 'baggage'
            propagators << ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new
          when 'solarwinds'
            propagators << SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
          end
        end
      end

      @@config[:propagators] = propagators
    end

    #
    #
    #
    def self.resolve_exporter
      exporter = @@config_map['OpenTelemetry::Exporter']
      if exporter
        @@config[:exporter] = exporter
        @@config_map.delete('OpenTelemetry::Exporter')
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/otel_config] The customer provided exporter #{exporter.name} is used."
      else
        otel_trace_exporter = ENV["OTEL_TRACES_EXPORTER"] || SolarWindsOTelAPM::Config[:otel_exporter] || 'solarwinds'
        case otel_trace_exporter
        when 'solarwinds'
          # @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: @@txn_manager, agent_enabled: @@agent_enabled)
          @@config[:exporter] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: @@txn_manager)
        end
      end
    end

    # solarwinds_inds has to be bigger then tracecontext_inds (at back)
    # we ensure propagators_list contains tracecontext and solarwinds
    # param: type_propagators: Array of String/Module
    def self.correct_order?(type_propagators)
      tracecontext_inds = type_propagators.find_index(::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator)
      solarwinds_inds   = type_propagators.find_index(SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator)

      if tracecontext_inds.nil? && solarwinds_inds.nil?
        tracecontext_inds = type_propagators.find_index('tracecontext')
        solarwinds_inds   = type_propagators.find_index('solarwinds')
      end

      SolarWindsOTelAPM.logger.debug "tracecontext_inds: #{tracecontext_inds}; solarwinds_inds: #{solarwinds_inds}"
      solarwinds_inds > tracecontext_inds ? true : false
    end

    def self.propagator?(propagator)
      begin
        if propagator.methods.include?(:extract) && propagator.methods.include?(:inject) 
          true
        else
          SolarWindsOTelAPM.logger.warn "solarwinds_otel_apm/otel_config] #{propagator} is not a proper propagator. Check if your propagator contains function inject and extract."
          false
        end
      rescue StandardError => e
        SolarWindsOTelAPM.logger.warn "solarwinds_otel_apm/otel_config] Check propagator #{propagator} failed. Error: #{e.message}"
        false
      end
    end

    def self.resolve_span_processor
      @@config[:span_processor] = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor.new(@@config[:exporter], @@txn_manager)
    end

    def self.exporter?(exporter)
      return false if exporter.nil?
      return false unless exporter.methods.include?(:export)
      true
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
    def self.resolve_config_map_for_instrumentation
      response_propagators_list = [SolarWindsOTelAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new]
      if @@config_map["OpenTelemetry::Instrumentation::Rack"]
        @@config_map["OpenTelemetry::Instrumentation::Rack"][:response_propagators] = response_propagators_list
      else
        @@config_map["OpenTelemetry::Instrumentation::Rack"] = {response_propagators: response_propagators_list}
      end
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
    # Default using the use_all to load all instrumentation 
    # With specific instrumentation disabled, use {:enabled: false} in config
    # SolarWindsOTelAPM::OTelConfig.initialize do |config|
    #   config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
    #   config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
    # end
    #
    def self.initialize
      yield @@config_map if block_given?

      validate_propagator
      validate_exporter

      return unless @@agent_enabled

      resolve_service_name
      resolve_propagators
      resolve_sampler
      resolve_exporter
      resolve_span_processor
      resolve_config_map_for_instrumentation

      print_config if SolarWindsOTelAPM.logger.level.zero?

      if defined?(::OpenTelemetry::SDK::Configurator)
        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = @@config[:service_name]
          c.add_span_processor(@@config[:span_processor])
          c.propagators = @@config[:propagators]
          c.use_all(@@config_map)
        end
      end

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = @@config[:sampler]
      nil
    end
  end
end