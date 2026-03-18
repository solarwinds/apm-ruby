# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'logger'
require './lib/solarwinds_apm/config'

describe 'Config Test' do
  describe '#config_file_from_env' do
    after do
      ENV.delete('SW_APM_CONFIG_RUBY')
    end

    it 'with empty SW_APM_CONFIG_RUBY should return nil' do
      ENV['SW_APM_CONFIG_RUBY'] = 'tmp/'
      config_file = SolarWindsAPM::Config.config_file_from_env
      assert_nil(config_file)
    end

    it 'with correct SW_APM_CONFIG_RUBY should return file' do
      ENV['SW_APM_CONFIG_RUBY'] = 'lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb'
      config_file = SolarWindsAPM::Config.config_file_from_env
      _(config_file).must_equal 'lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb'
    end

    it 'with correct SW_APM_CONFIG_RUBY path should return file path' do
      ENV['SW_APM_CONFIG_RUBY'] = 'test/solarwinds_apm/'
      config_file = SolarWindsAPM::Config.config_file_from_env
      _(config_file).must_equal 'test/solarwinds_apm/solarwinds_apm_config.rb'
    end

    it 'with incorrect SW_APM_CONFIG_RUBY path should return nil' do
      ENV['SW_APM_CONFIG_RUBY'] = 'test/opentelemetry/'
      config_file = SolarWindsAPM::Config.config_file_from_env
      assert_nil(config_file)
    end
  end

  describe '#enable_disable_config' do
    before do
      SolarWindsAPM::Config.initialize
    end

    after do
      ENV.delete('DUMMY_KEY')
    end

    it 'with env override every config file configuration (enabled)' do
      ENV['DUMMY_KEY'] = 'enabled'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :disabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with env override every config file configuration (enabled) with default enabled' do
      ENV['DUMMY_KEY'] = 'disabled'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :enabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'with env override every config file configuration (enabled) with default disabled' do
      ENV['DUMMY_KEY'] = 'disabled'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :enabled, :disabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'without env, obey config file configuration' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :disabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'with wrong value, use default :enabled' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :foo, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with string enabled value, use default :enabled' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, 'enabled', :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with string disabled value, use default :enabled' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, 'disabled', :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with empty env key, use config file configuration (disabled)' do
      SolarWindsAPM::Config.enable_disable_config('', :dummy_key, :disabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'with empty env key, use config file configuration (enabled)' do
      SolarWindsAPM::Config.enable_disable_config('', :dummy_key, :enabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with wrong env value and config value, use default :enabled' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :disabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end

    it 'with wrong env value and config value, use default :disabled' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, :disabled, :disabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'with wrong env value and wrong config value, use default :enabled' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, 'foo', :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :enabled
    end
  end

  describe '#enable_disable_config for boolean value' do
    before do
      SolarWindsAPM::Config.initialize
    end

    after do
      ENV.delete('DUMMY_KEY')
    end

    # enable_disable_config(env_var, key, value, default, bool=false)
    it 'with correct env true override config false ' do
      ENV['DUMMY_KEY'] = 'true'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with correct env false override config false ' do
      ENV['DUMMY_KEY'] = 'false'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with wrong env, use default true' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with wrong env, use default false' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with config env true' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with config env false' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, false, true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with wrong config env, use default false' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, 'true', false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with wrong config env, use default true' do
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, 'true', true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with empty env, config env true, use default false, should be true' do
      ENV['DUMMY_KEY'] = 'true'
      SolarWindsAPM::Config.enable_disable_config('', :dummy_key, true, false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with empty env, empty config env, use default false, should be false' do
      ENV['DUMMY_KEY'] = ''
      SolarWindsAPM::Config.enable_disable_config('', :dummy_key, '', false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with empty env, empty config env, use default true, should be true' do
      SolarWindsAPM::Config.enable_disable_config('', :dummy_key, '', true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end
  end

  describe '#set_log_level' do
    before do
      SolarWindsAPM::Config.initialize
      @current_debug_level = ENV.fetch('SW_APM_DEBUG_LEVEL', nil)
      ENV.delete('SW_APM_DEBUG_LEVEL')
    end

    after do
      ENV['SW_APM_DEBUG_LEVEL'] = @current_debug_level
    end

    it 'debug_level is out of range use default INFO' do
      SolarWindsAPM::Config[:debug_level] = 7
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::INFO
    end

    it 'debug_level is in the range' do
      SolarWindsAPM::Config[:debug_level] = 1
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::ERROR
    end

    it 'debug_level is in the range with -1 as disable sw logger' do
      SolarWindsAPM::Config[:debug_level] = -1
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::FATAL
      assert_nil(SolarWindsAPM.logger.instance_variable_get(:@logdev))
    end

    it 'env var override config' do
      ENV['SW_APM_DEBUG_LEVEL'] = '3'
      SolarWindsAPM::Config[:debug_level] = 1
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::INFO
      ENV.delete('SW_APM_DEBUG_LEVEL')
    end

    it 'env var is in the range with 2' do
      SolarWindsAPM::Config[:debug_level] = 2
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::WARN
    end

    it 'env var is in the range with 3' do
      SolarWindsAPM::Config[:debug_level] = 3
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::INFO
    end

    it 'env var is in the range with 0' do
      SolarWindsAPM::Config[:debug_level] = 0
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::FATAL
    end

    it 'env var is in the range with 4' do
      SolarWindsAPM::Config[:debug_level] = 4
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::DEBUG
    end

    it 'env var override config but out of range' do
      ENV['SW_APM_DEBUG_LEVEL'] = '7'
      SolarWindsAPM::Config[:debug_level] = 1
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::INFO
      ENV.delete('SW_APM_DEBUG_LEVEL')
    end

    it 'env var override config but out of range by less than 0' do
      ENV['SW_APM_DEBUG_LEVEL'] = '-10'
      SolarWindsAPM::Config[:debug_level] = 1
      SolarWindsAPM::Config.set_log_level
      _(SolarWindsAPM.logger.level).must_equal Logger::INFO
      ENV.delete('SW_APM_DEBUG_LEVEL')
    end
  end

  describe 'general checking on []=' do
    # this load the default config
    # oboe_init_options_test.rb also test if env override the config file, but not include below key
    before do
      SolarWindsAPM::Config.initialize
    end

    it 'initializes with correct default values for all configuration keys' do
      assert_nil(SolarWindsAPM::Config[:sampling_rate])
      assert_nil(SolarWindsAPM::Config[:sample_rate])
      _(SolarWindsAPM::Config[:transaction_settings].class).must_equal Array
      _(SolarWindsAPM::Config[:trigger_tracing_mode]).must_equal :enabled
      _(SolarWindsAPM::Config[:tracing_mode]).must_equal :enabled
      _(SolarWindsAPM::Config[:debug_level]).must_equal 3
      _(SolarWindsAPM::Config[:log_traceId]).must_equal :never
      _(SolarWindsAPM::Config[:tag_sql]).must_equal false
    end

    it 'check SW_APM_TRIGGER_TRACING_MODE env var overriding' do
      ENV['SW_APM_TRIGGER_TRACING_MODE'] = 'disabled'
      SolarWindsAPM::Config.initialize
      _(SolarWindsAPM::Config[:trigger_tracing_mode]).must_equal :disabled
      ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
    end

    it 'check SW_APM_TAG_SQL env var overriding' do
      ENV['SW_APM_TAG_SQL'] = 'true'
      SolarWindsAPM::Config.initialize
      _(SolarWindsAPM::Config[:tag_sql]).must_equal true
      ENV.delete('SW_APM_TAG_SQL')
    end
  end

  describe 'enable_disable_config tested via []= assignment' do
    it 'uses env var when valid enabled/disabled value' do
      original = ENV.fetch('SW_APM_TRIGGER_TRACING_MODE', nil)
      ENV['SW_APM_TRIGGER_TRACING_MODE'] = 'disabled'

      SolarWindsAPM::Config[:trigger_tracing_mode] = :enabled
      assert_equal :disabled, SolarWindsAPM::Config[:trigger_tracing_mode]
    ensure
      if original
        ENV['SW_APM_TRIGGER_TRACING_MODE'] = original
      else
        ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      end
    end

    it 'uses default for invalid env var' do
      original = ENV.fetch('SW_APM_TRIGGER_TRACING_MODE', nil)
      ENV['SW_APM_TRIGGER_TRACING_MODE'] = 'invalid_value'

      SolarWindsAPM::Config[:trigger_tracing_mode] = :enabled
      assert_equal :enabled, SolarWindsAPM::Config[:trigger_tracing_mode]
    ensure
      if original
        ENV['SW_APM_TRIGGER_TRACING_MODE'] = original
      else
        ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      end
    end

    it 'accepts boolean config with true/false env var' do
      original = ENV.fetch('SW_APM_TAG_SQL', nil)
      ENV['SW_APM_TAG_SQL'] = 'true'

      SolarWindsAPM::Config[:tag_sql] = false
      assert_equal true, SolarWindsAPM::Config[:tag_sql]
    ensure
      if original
        ENV['SW_APM_TAG_SQL'] = original
      else
        ENV.delete('SW_APM_TAG_SQL')
      end
    end

    it 'uses default for invalid boolean env var' do
      original = ENV.fetch('SW_APM_TAG_SQL', nil)
      ENV['SW_APM_TAG_SQL'] = 'invalid_bool'

      SolarWindsAPM::Config[:tag_sql] = true
      assert_equal false, SolarWindsAPM::Config[:tag_sql]
    ensure
      if original
        ENV['SW_APM_TAG_SQL'] = original
      else
        ENV.delete('SW_APM_TAG_SQL')
      end
    end

    it 'accepts value from code when env var not set' do
      original = ENV.fetch('SW_APM_TRIGGER_TRACING_MODE', nil)
      ENV.delete('SW_APM_TRIGGER_TRACING_MODE')

      SolarWindsAPM::Config[:trigger_tracing_mode] = :disabled
      assert_equal :disabled, SolarWindsAPM::Config[:trigger_tracing_mode]
    ensure
      if original
        ENV['SW_APM_TRIGGER_TRACING_MODE'] = original
      else
        ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      end
    end

    it 'uses default for invalid code value' do
      original = ENV.fetch('SW_APM_TRIGGER_TRACING_MODE', nil)
      ENV.delete('SW_APM_TRIGGER_TRACING_MODE')

      SolarWindsAPM::Config[:trigger_tracing_mode] = 'invalid_string'
      assert_equal :enabled, SolarWindsAPM::Config[:trigger_tracing_mode]
    ensure
      if original
        ENV['SW_APM_TRIGGER_TRACING_MODE'] = original
      else
        ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      end
    end
  end

  describe 'true?' do
    it 'returns true for string true' do
      assert SolarWindsAPM::Config.true?('true')
    end

    it 'returns true for string TRUE' do
      assert SolarWindsAPM::Config.true?('TRUE')
    end

    it 'returns false for string false' do
      refute SolarWindsAPM::Config.true?('false')
    end
  end

  describe 'boolean?' do
    it 'returns true for true' do
      assert SolarWindsAPM::Config.boolean?(true)
    end

    it 'returns true for false' do
      assert SolarWindsAPM::Config.boolean?(false)
    end

    it 'returns false for string' do
      refute SolarWindsAPM::Config.boolean?('true')
    end
  end

  describe 'symbol?' do
    it 'returns true for :enabled' do
      assert SolarWindsAPM::Config.symbol?(:enabled)
    end

    it 'returns true for :disabled' do
      assert SolarWindsAPM::Config.symbol?(:disabled)
    end

    it 'returns false for string' do
      refute SolarWindsAPM::Config.symbol?('enabled')
    end
  end

  describe '[]= key handling' do
    it 'warns on deprecated sampling_rate' do
      original = SolarWindsAPM::Config[:sampling_rate]
      SolarWindsAPM::Config[:sampling_rate] = 100
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:sampling_rate] = original
    end

    it 'warns on deprecated sample_rate' do
      original = SolarWindsAPM::Config[:sample_rate]
      SolarWindsAPM::Config[:sample_rate] = 100
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:sample_rate] = original
    end

    it 'warns on deprecated ec2_metadata_timeout' do
      original = SolarWindsAPM::Config[:ec2_metadata_timeout]
      SolarWindsAPM::Config[:ec2_metadata_timeout] = 1000
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:ec2_metadata_timeout] = original
    end

    it 'warns on deprecated http_proxy' do
      original = SolarWindsAPM::Config[:http_proxy]
      SolarWindsAPM::Config[:http_proxy] = 'http://proxy'
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:http_proxy] = original
    end

    it 'warns on deprecated hostname_alias' do
      original = SolarWindsAPM::Config[:hostname_alias]
      SolarWindsAPM::Config[:hostname_alias] = 'alias'
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:hostname_alias] = original
    end

    it 'warns on deprecated log_args' do
      original = SolarWindsAPM::Config[:log_args]
      SolarWindsAPM::Config[:log_args] = true
    ensure
      SolarWindsAPM::Config.class_variable_get(:@@config)[:log_args] = original
    end

    it 'handles tracing_mode assignment' do
      original = ENV.fetch('SW_APM_TRIGGER_TRACING_MODE', nil)
      ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      assert_equal :enabled, SolarWindsAPM::Config[:tracing_mode]
    ensure
      if original
        ENV['SW_APM_TRIGGER_TRACING_MODE'] = original
      else
        ENV.delete('SW_APM_TRIGGER_TRACING_MODE')
      end
    end

    it 'handles transaction_settings with disabled regexp' do
      settings = [{ regexp: '/health', tracing: :disabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
      refute_nil SolarWindsAPM::Config[:disabled_regexps]
    end

    it 'handles transaction_settings with enabled regexp' do
      settings = [{ regexp: '/api', tracing: :enabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
      refute_nil SolarWindsAPM::Config[:enabled_regexps]
    end

    it 'handles empty transaction_settings' do
      SolarWindsAPM::Config[:transaction_settings] = []
      assert_nil SolarWindsAPM::Config[:enabled_regexps]
      assert_nil SolarWindsAPM::Config[:disabled_regexps]
    end

    it 'handles non-array transaction_settings' do
      SolarWindsAPM::Config[:transaction_settings] = 'invalid'
      assert_nil SolarWindsAPM::Config[:enabled_regexps]
      assert_nil SolarWindsAPM::Config[:disabled_regexps]
    end

    it 'handles transaction_settings with Regexp object' do
      settings = [{ regexp: %r{/health}, tracing: :disabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
      refute_nil SolarWindsAPM::Config[:disabled_regexps]
    end

    it 'handles transaction_settings with invalid regexp string' do
      settings = [{ regexp: '(invalid[', tracing: :disabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
      # Invalid regexp is ignored
    end

    it 'handles transaction_settings with empty regexp string' do
      settings = [{ regexp: '', tracing: :disabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
    end

    it 'handles transaction_settings with empty Regexp' do
      settings = [{ regexp: Regexp.new(''), tracing: :disabled }]
      SolarWindsAPM::Config[:transaction_settings] = settings
    end

    it 'handles transaction_settings without tracing key' do
      settings = [{ regexp: '/test' }]
      SolarWindsAPM::Config[:transaction_settings] = settings
      # No tracing key defaults to disabled
    end

    it 'handles generic key assignment' do
      SolarWindsAPM::Config[:custom_key] = 'custom_value'
      assert_equal 'custom_value', SolarWindsAPM::Config[:custom_key]
    end
  end

  describe 'config_file_from_env' do
    it 'returns nil for non-existent file' do
      original = ENV.fetch('SW_APM_CONFIG_RUBY', nil)
      ENV['SW_APM_CONFIG_RUBY'] = '/nonexistent/path/file.rb'
      result = SolarWindsAPM::Config.config_file_from_env
      assert_nil result
    ensure
      if original
        ENV['SW_APM_CONFIG_RUBY'] = original
      else
        ENV.delete('SW_APM_CONFIG_RUBY')
      end
    end
  end

  describe 'update! and merge!' do
    it 'updates config with hash data' do
      SolarWindsAPM::Config.update!({ test_update_key: 'test_value' })
      assert_equal 'test_value', SolarWindsAPM::Config[:test_update_key]
    end

    it 'merge! is an alias for update!' do
      SolarWindsAPM::Config[:test_merge_key] = 'test_value'
      assert_equal 'test_value', SolarWindsAPM::Config[:test_merge_key]
    end
  end

  describe 'print_config' do
    it 'prints config without error' do
      result = SolarWindsAPM::Config.print_config
      assert_nil result
    end
  end
end
