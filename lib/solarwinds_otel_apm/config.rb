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
      config_files << config_from_env if ENV.has_key?('SW_APM_CONFIG_RUBY')

      # Check for default config file
      config_file = File.join(Dir.pwd, 'solarwinds_otel_apm_config.rb')
      config_files << config_file if File.exist?(config_file)

      SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Multiple configuration files configured, using the first one listed: #{config_files.join(', ')}" if config_files.size > 1
      load(config_files[0]) if config_files.size > 0

      set_log_level        # sets SolarWindsOTelAPM::Config[:debug_level], SolarWindsOTelAPM.logger.level
      set_verbose_level    # the verbose setting is only relevant for ruby, ENV['SW_APM_GEM_VERBOSE'] overrides
    end

    def self.config_from_env
      config_files = []
      if File.exist?(ENV['SW_APM_CONFIG_RUBY']) && !File.directory?(ENV['SW_APM_CONFIG_RUBY'])
        config_files << ENV['SW_APM_CONFIG_RUBY']
      elsif File.exist?(File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_otel_apm_config.rb'))
        config_files << File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_otel_apm_config.rb')
      else
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Could not find the configuration file set by the SW_APM_CONFIG_RUBY environment variable:  #{ENV['SW_APM_CONFIG_RUBY']}"
      end
      config_files
    end

    def self.set_verbose_level
      verbose = ENV.has_key?('SW_APM_GEM_VERBOSE')? ENV['SW_APM_GEM_VERBOSE'].downcase == 'true' : nil
      SolarWindsOTelAPM::Config[:verbose] = verbose
    end

    def self.set_log_level
      SolarWindsOTelAPM::Config[:debug_level] = 3 unless (-1..6).include?(SolarWindsOTelAPM::Config[:debug_level])

      # let's find and use the equivalent debug level for ruby
      debug_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsOTelAPM::Config[:debug_level] || 3).to_i
      SolarWindsOTelAPM.logger.level = debug_level < 0 ? 6 : [4 - debug_level, 0].max
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      SolarWindsOTelAPM.logger.warn "# General configurations"
      @@config.each do |k,v|
        SolarWindsOTelAPM.logger.warn "Config Key/Value: #{k}, #{v.inspect}"
      end
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a default configuration.
    # The defaults are read from the template configuration file.
    # 
    def self.initialize(_data={})
      @@config[:profiling] = :disabled
      @@config[:profiling_interval] = 5

      # Always load the template, it has all the keys and defaults defined,
      # no guarantee of completeness in the user's config file
      load(File.join(File.dirname(File.dirname(__FILE__)), 'rails/generators/solarwinds_otel_apm/templates/solarwinds_otel_apm_initializer.rb'))
    end

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
    def self.[]=(key, value)
      key = key.to_sym
      @@config[key] = value

      case key
      when :sampling_rate
        SolarWindsOTelAPM.logger.warn '[solarwinds_otel_apm/config] sampling_rate is not a supported setting for SolarWindsOTelAPM::Config.  ' \
                                 'Please use :sample_rate.'

      when :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :sample_rate must be a number between 0 and 1000000 (1m) " \
                                   "(provided: #{value}), corrected to 0"
          value = 0
        end

        # Validate :sample_rate value
        unless value.between?(0, 1e6)
          new_value = value < 0 ? 0 : 1_000_000
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] :sample_rate must be between 0 and 1000000 (1m) " \
                                   "(provided: #{value}), corrected to #{new_value}"
        end

        # Assure value is an integer
        @@config[key.to_sym] = new_value.to_i
        SolarWindsOTelAPM.sample_rate(new_value) if SolarWindsOTelAPM.loaded

      when :profiling
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Profiling feature is currently not available." 
        @@config[:profiling] = :disabled

      when  :profiling_interval
        SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Profiling feature is currently not available. :profiling_interval setting is not configured." 
        value = if value.is_a?(Integer) && value > 0
                  [100, value].min
                else
                  10
                end
        @@config[:profiling_interval] = value
        # CProfiler may not be loaded yet, the profiler will send the value
        # after it is loaded
        SolarWindsOTelAPM::CProfiler.interval_setup(value) if defined? SolarWindsOTelAPM::CProfiler

      when :transaction_settings
        SolarWindsOTelAPM::API.compile_settings(value)

      when :tracing_mode
        # ALL TRACING COMMUNICATION TO OBOE IS NOW HANDLED BY TransactionSettings
        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym

      else
        @@config[key.to_sym] = value

      end
    end
  end
end

SolarWindsOTelAPM::Config.initialize
