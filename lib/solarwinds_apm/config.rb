# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the solarwinds_apm gem.
  #
  # Use SolarWindsAPM::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}
    @@instrumentation = [:action_controller, :action_controller_api, :action_view,
                         :active_record, :bunnyclient, :bunnyconsumer, :curb,
                         :dalli, :delayed_jobclient, :delayed_jobworker,
                         :excon, :faraday, :graphql, :grpc_client, :grpc_server, :grape,
                         :httpclient, :nethttp, :memcached, :mongo, :moped, :padrino, :rack, :redis,
                         :resqueclient, :resqueworker, :rest_client,
                         :sequel, :sidekiqclient, :sidekiqworker, :sinatra, :typhoeus,
                         :curb, :excon, :faraday, :httpclient, :nethttp, :rest_client, :typhoeus]

    ##
    # load_config_file
    #
    # There are 3 possible locations for the config file:
    # Rails default, ENV['SW_APM_CONFIG_RUBY'], or the gem's default
    # Config will be used in OboeInitOptions but ENV variable has higher priority
    #   e.g. ENV['SW_APM_SERVICE_KEY'] || SolarWindsAPM::Config[:service_key]
    #
    # Hierarchie:
    # 1 - Rails default: config/initializers/solarwinds_apm.rb
    #     (also loaded  by Rails, but we can't reliably determine if Rails is running)
    # 2 - ENV['SW_APM_CONFIG_RUBY']
    # 3 - Gem default: <startup_dir>/solarwinds_apm_config.rb
    #
    def self.load_config_file
      config_files = []

      # Check for the rails config file
      config_file = File.join(Dir.pwd, 'config/initializers/solarwinds_apm.rb')
      config_files << config_file if File.exist?(config_file)

      # Check for file set by env variable
      config_files << config_from_env if ENV.has_key?('SW_APM_CONFIG_RUBY')

      # Check for default config file
      config_file = File.join(Dir.pwd, 'solarwinds_apm_config.rb')
      config_files << config_file if File.exist?(config_file)

      SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Multiple configuration files configured, using the first one listed: #{config_files.join(', ')}"} if config_files.size > 1
      load(config_files[0]) if config_files.size > 0

      set_log_level        # sets SolarWindsAPM::Config[:debug_level], SolarWindsAPM.logger.level
    end

    def self.config_from_env
      if File.exist?(ENV['SW_APM_CONFIG_RUBY']) && !File.directory?(ENV['SW_APM_CONFIG_RUBY'])
        config_file = ENV['SW_APM_CONFIG_RUBY']
      elsif File.exist?(File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_apm_config.rb'))
        config_file = File.join(ENV['SW_APM_CONFIG_RUBY'], 'solarwinds_apm_config.rb')
      else
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Could not find the configuration file set by the SW_APM_CONFIG_RUBY environment variable:  #{ENV['SW_APM_CONFIG_RUBY']}"}
      end
      config_file
    end

    def self.set_log_level
      SolarWindsAPM::Config[:debug_level] = 3 unless (-1..6).cover?(SolarWindsAPM::Config[:debug_level])

      # let's find and use the equivalent debug level for ruby
      debug_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
      SolarWindsAPM.logger.level = debug_level < 0 ? 6 : [4 - debug_level, 0].max
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] General configurations list blow:"}
      @@config.each do |k,v|
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Config Key/Value: #{k}, #{v.inspect}"}
      end
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a default configuration.
    # The defaults are read from the template configuration file.
    #
    def self.initialize(_data={})
      # for config file backward compatibility
      @@instrumentation.each {|inst| @@config[inst] = {}}
      @@config[:transaction_name] = {}

      # Always load the template, it has all the keys and defaults defined,
      # no guarantee of completeness in the user's config file
      load(File.join(File.dirname(File.dirname(__FILE__)), 'rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb'))
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
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] sampling_rate is not a supported setting for SolarWindsAPM::Config. Please use :sample_rate."}

      when :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] :sample_rate must be a number between 0 and 1000000 (1m) (provided: #{value}), corrected to 0"}
          value = 0
        end

        # Validate :sample_rate value
        unless value.between?(0, 1e6)
          new_value = value < 0 ? 0 : 1_000_000
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] :sample_rate must be between 0 and 1000000 (1m) (provided: #{value}), corrected to #{new_value}"}
        end

        # Assure value is an integer
        @@config[key.to_sym] = new_value.to_i
        SolarWindsAPM.sample_rate(new_value) if SolarWindsAPM.loaded

      when :transaction_settings
        compile_settings(value)

      when :tracing_mode
        # ALL TRACING COMMUNICATION TO OBOE IS NOW HANDLED BY TransactionSettings
        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym

      when :tag_sql
        if ENV.has_key?('SW_APM_TAG_SQL')
          @@config[key.to_sym] = (ENV['SW_APM_TAG_SQL'] == 'true')
        else
          @@config[key.to_sym] = value
        end

      else
        @@config[key.to_sym] = value

      end
    end

    ####### Below are private methods are not customer facing #######

    def self.compile_settings(settings)
      if !settings.is_a?(Array) || settings.empty?
        reset_regexps
        return
      end

      # `tracing: disabled` is the default
      disabled = settings.select { |v| !v.has_key?(:tracing) || v[:tracing] == :disabled }
      enabled  = settings.select { |v| v[:tracing] == :enabled }

      SolarWindsAPM::Config[:enabled_regexps] = compile_regexp(enabled)
      SolarWindsAPM::Config[:disabled_regexps] = compile_regexp(disabled)
    end
    private_class_method :compile_settings

    def self.compile_regexp(settings)
      regexp_regexp = compile_settings_regexp(settings)
      regexps       = [regexp_regexp].flatten.compact
      regexps.empty? ? nil : regexps
    end
    private_class_method :compile_regexp

    def self.compile_settings_regexp(value)
      regexps = value.select do |v|
        v.has_key?(:regexp) &&
          !(v[:regexp].is_a?(String) && v[:regexp].empty?) &&
          !(v[:regexp].is_a?(Regexp) && v[:regexp].inspect == '//')
      end

      regexps.map! do |v|
        begin
          v[:regexp].is_a?(String) ? Regexp.new(v[:regexp], v[:opts]) : Regexp.new(v[:regexp])
        rescue StandardError => e
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Problem compiling transaction_settings item #{v}, will ignore. Error: #{e.message}"}
          nil
        end
      end
      regexps.keep_if { |v| !v.nil? }
      regexps.empty? ? nil : regexps
    end
    private_class_method :compile_settings_regexp

    def self.reset_regexps
      SolarWindsAPM::Config[:enabled_regexps] = nil
      SolarWindsAPM::Config[:disabled_regexps] = nil
    end
    private_class_method :reset_regexps
  end
end

SolarWindsAPM::Config.initialize
