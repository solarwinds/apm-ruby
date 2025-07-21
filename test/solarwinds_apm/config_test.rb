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

    it 'with nil env key, use config file configuration (disabled)' do
      SolarWindsAPM::Config.enable_disable_config(nil, :dummy_key, :disabled, :enabled)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal :disabled
    end

    it 'with nil env key, use config file configuration (enabled)' do
      SolarWindsAPM::Config.enable_disable_config(nil, :dummy_key, :enabled, :enabled)
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

    it 'with wrong env, use default true ' do
      ENV['DUMMY_KEY'] = 'foo'
      SolarWindsAPM::Config.enable_disable_config('DUMMY_KEY', :dummy_key, true, true, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with wrong env, use default true ' do
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

    it 'with nil env, config env true, use default false, should be true' do
      ENV['DUMMY_KEY'] = 'true'
      SolarWindsAPM::Config.enable_disable_config(nil, :dummy_key, true, false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal true
    end

    it 'with nil env, empty config env, use default false, should be false' do
      ENV['DUMMY_KEY'] = ''
      SolarWindsAPM::Config.enable_disable_config(nil, :dummy_key, '', false, bool: true)
      _(SolarWindsAPM::Config[:dummy_key]).must_equal false
    end

    it 'with nil env, empty config env, use default true, should be true' do
      SolarWindsAPM::Config.enable_disable_config(nil, :dummy_key, '', true, bool: true)
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

    it 'check default setting' do
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
end
