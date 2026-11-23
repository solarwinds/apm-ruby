# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'set'
require_relative 'support/secure_path'

module SolarWindsAPM
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the solarwinds_apm gem.
  #
  # Use SolarWindsAPM::Config.show to view the entire nested hash.
  #
  module Config
    SW_LOG_LEVEL_MAPPING = { -1 => { stdlib: ::Logger::FATAL, otel: 'fatal' },
                             0 => { stdlib: ::Logger::FATAL, otel: 'fatal' },
                             1 => { stdlib: ::Logger::ERROR, otel: 'error' },
                             2 => { stdlib: ::Logger::WARN, otel: 'warn' },
                             3 => { stdlib: ::Logger::INFO, otel: 'info' },
                             4 => { stdlib: ::Logger::DEBUG, otel: 'debug' },
                             5 => { stdlib: ::Logger::DEBUG, otel: 'debug' },
                             6 => { stdlib: ::Logger::DEBUG, otel: 'debug' } }.freeze

    @@config = {}

    RAILS_CONFIG_FILE = 'config/initializers/solarwinds_apm.rb'
    LEGACY_CONFIG_FILE = 'solarwinds_apm_config.rb'

    ##
    # load_config_file
    #
    # Selects and loads at most one Ruby config file.
    # Config will be used in OboeInitOptions but ENV variable has higher priority
    #   e.g. ENV['SW_APM_SERVICE_KEY'] || SolarWindsAPM::Config[:service_key]
    #
    # Selection:
    # 1 - If ENV['SW_APM_CONFIG_RUBY'] is set, it must be the absolute path of the config file.
    #     If it is relative or can't be found, no other location is probed (fail closed).
    # 2 - Otherwise, only for Rails applications, the prescribed Rails initializer
    #     <Rails root>/config/initializers/solarwinds_apm.rb (also loaded later by Rails itself).
    #
    # Only the SW_APM_CONFIG_RUBY file is checked with SolarWindsAPM::SecurePath.trusted_path, and its
    # validated real path is what gets loaded. The Rails initializer isn't checked, because Rails loads
    # every file in config/initializers regardless.
    #
    def self.load_config_file
      env_path = ENV.fetch('SW_APM_CONFIG_RUBY', '').strip
      config_file = env_path.empty? ? rails_config_file : config_file_from_env(env_path)
      load(config_file) if config_file

      set_log_level # sets SolarWindsAPM::Config[:debug_level], SolarWindsAPM.logger.level
    end

    def self.config_file_from_env(env_path)
      unless File.absolute_path?(env_path)
        SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] SW_APM_CONFIG_RUBY must be the absolute path of the configuration file (current setting is #{env_path}). No configuration file will be loaded." }
        return
      end

      unless File.file?(env_path)
        SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] Could not find the configuration file set by the SW_APM_CONFIG_RUBY environment variable: #{env_path}. No configuration file will be loaded." }
        return
      end

      SolarWindsAPM::SecurePath.trusted_path(env_path)
    end

    ##
    # rails_config_file
    #
    # Path of <Rails root>/config/initializers/solarwinds_apm.rb, or nil when Rails is not loaded,
    # its root can't be determined, or the file doesn't exist.
    # When the gem is required by Bundler.require, the Rails application class isn't defined yet
    # (Rails.root is nil), so fall back to the directory of the Gemfile that Rails' config/boot.rb
    # sets in BUNDLE_GEMFILE. Only an absolute BUNDLE_GEMFILE is used, never the current directory.
    #
    def self.rails_config_file
      rails_root = ''
      if defined?(::Rails) && ::Rails.respond_to?(:root)
        rails_root = ::Rails.root.to_s
        gemfile = ENV.fetch('BUNDLE_GEMFILE', '').strip
        rails_root = File.dirname(gemfile) if rails_root.empty? && File.absolute_path?(gemfile)
      end

      if rails_root.empty?
        legacy_file = File.join(Dir.pwd, LEGACY_CONFIG_FILE)
        SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] Set SW_APM_CONFIG_RUBY to its absolute path to load it. Legacy file #{LEGACY_CONFIG_FILE} is no longer loaded." } if File.file?(legacy_file)
        return nil
      end

      config_file = File.join(rails_root, RAILS_CONFIG_FILE)
      return config_file if File.file?(config_file)

      SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] Rails configuration file #{config_file} not found." }
      nil
    rescue StandardError => e
      SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] Failed to determine Rails root: #{e.message}" }
      nil
    end

    def self.set_log_level
      log_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i

      SolarWindsAPM.logger = ::Logger.new(nil) if log_level == -1

      SolarWindsAPM.logger.level = SW_LOG_LEVEL_MAPPING.dig(log_level, :stdlib) || ::Logger::INFO # default log level info
    end

    # e.g. enable_disable_config('STRING', :key, value, false, bool: true)
    def self.enable_disable_config(env_var, key, value, default, bool: false)
      raw_env_value  = ENV.fetch(env_var, '')
      env_value      = raw_env_value.downcase
      valid_env_values = bool ? %w[true false] : %w[enabled disabled]

      if !env_var.empty? && valid_env_values.include?(env_value)
        value = bool ? true?(env_value) : env_value.to_sym
      elsif !env_var.empty? && !raw_env_value.empty?
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] #{env_var} must be #{valid_env_values.join('/')} (current setting is #{raw_env_value}). Using default value: #{default}."
        end
        return @@config[key] = default
      end

      # Validate final value efficiently
      valid = bool ? boolean?(value) : symbol?(value)

      unless valid
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] :#{key} must be #{valid_env_values.join('/')}. Using default value: #{default}."
        end
        return @@config[key] = default
      end

      @@config[key] = value
    end

    def self.true?(obj)
      obj.to_s.casecmp('true').zero?
    end

    def self.boolean?(obj)
      [true, false].include?(obj)
    end

    def self.symbol?(obj)
      %i[enabled disabled].include?(obj)
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] General configurations list blow:" }
      @@config.each do |k, v|
        SolarWindsAPM.logger.debug do
          "[#{name}/#{__method__}] Config Key/Value: #{k}, #{v.inspect}"
        end
      end
      nil
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a default configuration.
    # The defaults are read from the template configuration file.
    # This will be called when require 'solarwinds_apm/config' happen
    #
    def self.initialize
      @@config[:transaction_name] = {}

      # Always load the template, it has all the keys and defaults defined,
      # no guarantee of completeness in the user's config file

      load(File.join(File.dirname(File.dirname(__FILE__)),
                     'rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb'))

      load_config_file

      print_config if SolarWindsAPM.logger.level.zero?
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
    # ENV always have higher precedence
    #
    def self.[]=(key, value)
      key = key.to_sym
      @@config[key] = value

      case key
      when :sampling_rate
        SolarWindsAPM.logger.warn do
          '[Deprecated] sampling_rate is not a supported setting for SolarWindsAPM::Config.'
        end

      when :sample_rate
        SolarWindsAPM.logger.warn do
          '[Deprecated] sample_rate is not a supported setting for SolarWindsAPM::Config.'
        end

      when :transaction_settings
        compile_settings(value)

      when :trigger_tracing_mode
        enable_disable_config('SW_APM_TRIGGER_TRACING_MODE', key, value, :enabled)

      when :tracing_mode
        enable_disable_config('', key, value, :enabled)

      when :tag_sql
        enable_disable_config('SW_APM_TAG_SQL', key, value, false, bool: true)

      when :ec2_metadata_timeout
        SolarWindsAPM.logger.warn { ':ec2_metadata_timeout is deprecated' }

      when :http_proxy
        SolarWindsAPM.logger.warn { ':http_proxy is deprecated' }

      when :hostname_alias
        SolarWindsAPM.logger.warn { ':hostname_alias is deprecated' }

      when :log_args
        SolarWindsAPM.logger.warn { ':log_args is deprecated' }

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

      # `tracing: disabled` is the default; below only separate the enabled and disabled settings
      result = settings.each_with_object({ enabled: [], disabled: [] }) do |setting, acc|
        if setting[:tracing] == :enabled
          acc[:enabled] << setting
        elsif !setting.key?(:tracing) || setting[:tracing] == :disabled
          acc[:disabled] << setting
        end
      end

      enabled = result[:enabled]
      disabled = result[:disabled]

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
        v.key?(:regexp) &&
          !(v[:regexp].is_a?(String) && v[:regexp].empty?) &&
          !(v[:regexp].is_a?(Regexp) && v[:regexp].inspect == '//')
      end

      regexps.map! do |v|
        v[:regexp].is_a?(String) ? Regexp.new(v[:regexp], v[:opts]) : Regexp.new(v[:regexp])
      rescue StandardError => e
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] Problem compiling transaction_settings item #{v}, will ignore. Error: #{e.message}"
        end
        nil
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
