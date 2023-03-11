# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsOTelAPM
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the solarwinds_otel_apm gem.
  #
  # Use SolarWindsOTelAPM::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    ##
    # load_config_file
    #
    # There are 3 possible locations for the config file:
    # Rails default, ENV['SW_APM_CONFIG_RUBY'], or the gem's default
    # Config will be used in OboeInitOptions but ENV variable has higher priority 
    #   e.g. ENV['SW_APM_SERVICE_KEY'] || SolarWindsOTelAPM::Config[:service_key]
    #
    # Hierarchie:
    # 1 - Rails default: config/initializers/solarwinds_otel_apm.rb
    #     (also loaded  by Rails, but we can't reliably determine if Rails is running)
    # 2 - ENV['SW_APM_CONFIG_RUBY']
    # 3 - Gem default: <startup_dir>/solarwinds_otel_apm_config.rb
    #
    def self.load_config_file
      config_files = []

      # Check for the rails config file
      config_file = File.join(Dir.pwd, 'config/initializers/solarwinds_otel_apm.rb')
      config_files << config_file if File.exist?(config_file)

      # Check for file set by env variable
      if ENV.key?('SW_APM_CONFIG_RUBY')
        if File.exist?(ENV['SW_APM_CONFIG_RUBY']) && !File.directory?(ENV['SW_APM_CONFIG_RUBY'])
          config_files << ENV['SW_APM_CONFIG_RUBY']
        elsif File.exist?(File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_otel_apm_config.rb'))
          config_files << File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_otel_apm_config.rb')
        else
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Could not find the configuration file set by the SW_APM_CONFIG_RUBY environment variable:  #{ENV['SW_APM_CONFIG_RUBY']}"
        end
      end

      # Check for default config file
      config_file = File.join(Dir.pwd, 'solarwinds_otel_apm_config.rb')
      config_files << config_file if File.exist?(config_file)

      unless config_files.empty? # we use the defaults from the template if there are no config files
        if config_files.size > 1
          SolarWindsOTelAPM.logger.warn [
                                     '[solarwinds_otel_apm/config] Multiple configuration files configured, using the first one listed: ',
                                     config_files.join(', ')
                                   ].join(' ')
        end
        load(config_files[0])
      end

      # sets SolarWindsOTelAPM::Config[:debug_level], SolarWindsOTelAPM.logger.level
      set_log_level

      # the verbose setting is only relevant for ruby, ENV['SW_APM_GEM_VERBOSE'] overrides
      if ENV.key?('SW_APM_GEM_VERBOSE')
        SolarWindsOTelAPM::Config[:verbose] = ENV['SW_APM_GEM_VERBOSE'].downcase == 'true'
      end
    end

    def self.set_log_level
      unless (-1..6).include?(SolarWindsOTelAPM::Config[:debug_level])
        SolarWindsOTelAPM::Config[:debug_level] = 3
      end
      
      # let's find and use the equivalent debug level for ruby
      debug_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsOTelAPM::Config[:debug_level] || 3).to_i
      if debug_level < 0
        # there should be no logging if SW_APM_DEBUG_LEVEL == -1
        # In Ruby level 5 is UNKNOWN and it can log, but level 6 is quiet
        SolarWindsOTelAPM.logger.level = 6
      else
        SolarWindsOTelAPM.logger.level = [4 - debug_level, 0].max
      end
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      SolarWindsAPM.logger.warn "# General configurations"
      @@config.each do |k,v|
        SolarWindsAPM.logger.warn "Config Key/Value: #{k}, #{v.inspect}"
      end
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a default configuration.
    # The defaults are read from the template configuration file.
    #
    # rubocop:disable Metrics/AbcSize
    def self.initialize(_data = {})
      @@config[:transaction_name] = {}

      @@config[:profiling] = :disabled
      @@config[:profiling_interval] = 5

      # Always load the template, it has all the keys and defaults defined,
      # no guarantee of completeness in the user's config file
      load(File.join(File.dirname(File.dirname(__FILE__)), 'rails/generators/solarwinds_otel_apm/templates/solarwinds_otel_apm_initializer.rb'))
    end
    # rubocop:enable Metrics/AbcSize

    def self.update!(data)
      data.each do |key, value|
        self[key] = value
      end
    end

    def self.merge!(data)
      update!(data)
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    ##
    # []=
    #
    # Config variable assignment method.  Here we validate and store the
    # assigned value(s) and trigger any secondary action needed.
    #
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def self.[]=(key, value)
      key = key.to_sym
      @@config[key] = value

      if key == :sampling_rate
        SolarWindsOTelAPM.logger.warn '[solarwinds_otel_apm/config] sampling_rate is not a supported setting for SolarWindsOTelAPM::Config.  ' \
                                 'Please use :sample_rate.'

      elsif key == :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :sample_rate must be a number between 0 and 1000000 (1m) " \
                                   "(provided: #{value}), corrected to 0"
          value = 0
        end

        # Validate :sample_rate value
        unless value.between?(0, 1e6)
          value_1 = value
          value = value_1 < 0 ? 0 : 1_000_000
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :sample_rate must be between 0 and 1000000 (1m) " \
                                   "(provided: #{value_1}), corrected to #{value}"
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i
        SolarWindsOTelAPM.set_sample_rate(value) if SolarWindsOTelAPM.loaded

      elsif key == :action_blacklist
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :action_blacklist has been deprecated and no longer functions."

      elsif key == :blacklist
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :blacklist has been deprecated and no longer functions."

      elsif key == :dnt_regexp
        if value.nil? || value == ''
          @@config[:dnt_compiled] = nil
        else
          @@config[:dnt_compiled] =
            Regexp.new(SolarWindsOTelAPM::Config[:dnt_regexp], SolarWindsOTelAPM::Config[:dnt_opts] || nil)
        end

      elsif key == :dnt_opts
        if SolarWindsOTelAPM::Config[:dnt_regexp] && SolarWindsOTelAPM::Config[:dnt_regexp] != ''
          @@config[:dnt_compiled] =
            Regexp.new(SolarWindsOTelAPM::Config[:dnt_regexp], SolarWindsOTelAPM::Config[:dnt_opts] || nil)
        end

      elsif key == :profiling
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Profiling feature is currently not available." 
        @@config[:profiling] = :disabled

      elsif key == :profiling_interval
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Profiling feature is currently not available. :profiling_interval setting is not configured." 
        if value.is_a?(Integer) && value > 0
          value = [100, value].min
        else
          value = 10
        end
        @@config[:profiling_interval] = value
        # CProfiler may not be loaded yet, the profiler will send the value
        # after it is loaded
        SolarWindsOTelAPM::CProfiler.set_interval(value) if defined? SolarWindsOTelAPM::CProfiler

      elsif key == :include_url_query_params # DEPRECATED
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@config[:rack][:log_args] = value

      elsif key == :include_remote_url_params # DEPRECATED
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@http_clients.each do |i|
          @@config[i][:log_args] = value
        end

      elsif key == :tracing_mode
      #   CAN'T DO `set_tracing_mode` ANYMORE, ALL TRACING COMMUNICATION TO OBOE
      #   IS NOW HANDLED BY TransactionSettings
      #   SolarWindsOTelAPM.set_tracing_mode(value.to_sym) if SolarWindsOTelAPM.loaded

        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym


      # otel-related config (will affect load_opentelemetry directly)
      # default is from solarwinds_otel_apm_initializer.rb
      # ENV always has the highest priorities
      # config.rb -> oboe_init_options
      elsif key == :otel_propagator # SWO_OTEL_PROPAGATOR
        @@config[key.to_sym] = value.to_sym

      elsif key == :otel_sampler    # SWO_OTEL_SAMPLER
        @@config[key.to_sym] = value.to_sym

      elsif key == :otel_processor  # SWO_OTEL_PROCESSOR
        @@config[key.to_sym] = value.to_sym

      elsif key == :service_name    # SWO_OTEL_SERVICE_NAME
        @@config[key.to_sym] = value.to_sym

      elsif key == :otel_response_propagator # SWO_OTEL_RESPONSE
        @@config[key.to_sym] = value.to_sym

      elsif key == :otel_exporter
        @@config[key.to_sym] = value.to_sym # SWO_OTEL_EXPORTER

      elsif key == :trigger_tracing_mode
        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym

      end
    end

  end
end

SolarWindsOTelAPM::Config.initialize
