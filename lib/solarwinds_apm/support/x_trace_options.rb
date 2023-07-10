# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  # XTraceOptions
  class XTraceOptions
    attr_reader :options, :signature, :trigger_trace, :timestamp, 
                :sw_keys, :custom_kvs, :ignored
    
    ##
    # use by Trigger Tracing
    # TODO - refactor for w3c when ticket ready
    #
    # Params:
    # +options+ : An X-Trace-Options @options string
    # +signature+ : hmac signature to pass on for verification
    #
    # populates:
    # - @force_trace (true|false)
    # - @app_id (as given by Pingdom)
    # - @probe_id (as given by Pingdom)
    # - @loc (2 characters given by Pingdom)
    # - @custom_kvs (hash)
    # - @ignored (array)
    #
    # split it up by ';' separator
    # kv assignment by '='
    # currently valid keys:
    # - force_trace (valid: 0,1) unless we use just a kv
    # - application_id (format defined by pingdom (no validation))
    # - probe_id
    # - custom_* (';=' not allowed in key), value (validate max. length)
    # - ts (unix timestamp)
    # - other keys will be reported in the response options as ignored

    SW_XTRACEOPTIONS_RESPONSE_KEY = 'xtrace_options_response'.freeze

    def initialize(context)
      SolarWindsAPM.logger.debug "####### x_trace_options context: #{context.inspect}"
      @context = context.dup
      @trigger_trace = false
      @custom_kvs = {}
      @sw_keys = nil
      @ignored = []
      @timestamp = 0
      @options = options_header
      @signature = obtain_signature

      @options&.split(/;+/)&.each do |val|
        k = val.split('=', 2)

        next unless k[0] # it can be nil, eg when the header starts with ';'

        k[0]&.strip!
        case k[0]
        when 'trigger-trace'
          if k[1]
            @ignored << 'trigger-trace'
          else
            @trigger_trace = true
          end
        when 'sw-keys'
          if @sw_keys
            SolarWindsAPM.logger.info "[solarwinds_apm/x-trace-options] Duplicate key: #{k[0]}"
          else
            @sw_keys = k[1].strip
          end
        when /^custom-[^\s]*$/
          if @custom_kvs[k[0]]
            SolarWindsAPM.logger.info "[solarwinds_apm/x-trace-options] Duplicate key: #{k[0]}"
          else
            @custom_kvs[k[0]] = k[1].strip
          end
        when 'ts'
          if @timestamp > 0
            SolarWindsAPM.logger.info "[solarwinds_apm/x-trace-options] Duplicate key: #{k[0]}"
          else
            @timestamp = k[1].to_i
          end
        else
          @ignored << k[0]
        end
      end
      SolarWindsAPM.logger.info("[solarwinds_apm/x-trace-options] Some keys were ignored: #{@ignored.join(',')}") unless @ignored.empty?
    end

    def add_kvs(kvs, settings)
      return unless settings.auth_ok?

      @custom_kvs.each { |k,v| kvs[k] = v } unless @custom_kvs.empty?
      kvs['SWKeys'] = @sw_keys if @sw_keys
      kvs['TriggeredTrace'] = true if settings.triggered_trace?
    end

    def obtain_signature
      # INTL_SWO_SIGNATURE_KEY = sw_signature
      signature = obtain_sw_value(SolarWindsAPM::Constants::INTL_SWO_SIGNATURE_KEY)
      SolarWindsAPM.logger.debug "####### x_trace_options option_signature: #{signature}"
      signature
    end

    def options_header
      # INTL_SWO_X_OPTIONS_KEY = sw_xtraceoptions 
      header = obtain_sw_value(SolarWindsAPM::Constants::INTL_SWO_X_OPTIONS_KEY)
      SolarWindsAPM.logger.debug "####### x_trace_options option_header: #{header}"
      header
    end

    def obtain_sw_value(type)
      sw_value = nil
      instance_variable = @context&.instance_variable_get("@entries")
      instance_variable&.each do |key, value|
        if key.instance_of?(::String)
          sw_value = value if key == type
          SolarWindsAPM.logger.debug "####### #{type} #{key}: #{value.inspect}"
        end
      end
      sw_value
    end

    def intify_trigger_trace
      @trigger_trace ? 1 : 0
    end

    def self.sw_xtraceoptions_response_key
      SW_XTRACEOPTIONS_RESPONSE_KEY
    end
  end
end
