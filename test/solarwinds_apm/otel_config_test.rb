# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'Loading Opentelemetry Test' do
  describe 'test response propagators configuration in otel_config' do
    before do
      clean_old_setting
      SolarWindsAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
      SolarWindsAPM::OTelConfig.class_variable_set(:@@config, {})
      SolarWindsAPM::OTelConfig.class_variable_set(:@@config_map, {})
    end

    it 'default_response_propagators' do
      SolarWindsAPM::OTelConfig.initialize
      rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
      _(rack_config.count).must_equal 1
      _(rack_config[:response_propagators][0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
    end

    it 'default_response_propagators_with_other_rack_config' do
      SolarWindsAPM::OTelConfig.initialize_with_config do |config|
        config['OpenTelemetry::Instrumentation::Rack'] = { record_frontend_span: true }
      end
      rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
      _(rack_config.count).must_equal 2
      _(rack_config[:record_frontend_span]).must_equal true
      _(rack_config[:response_propagators][0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
    end

    it 'default_response_propagators_with_other_response_propagators' do
      SolarWindsAPM::OTelConfig.initialize_with_config do |config|
        config['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: ['String'] }
      end
      rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
      _(rack_config.count).must_equal 1
      _(rack_config[:response_propagators].count).must_equal 2
      _(rack_config[:response_propagators][0]).must_equal 'String'
      _(rack_config[:response_propagators][1].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
    end

    it 'default_response_propagators_with_non_array_response_propagators' do
      SolarWindsAPM::OTelConfig.initialize_with_config do |config|
        config['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: 'String' }
      end
      rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
      _(rack_config.count).must_equal 1
      _(rack_config[:response_propagators].class).must_equal String
    end
  end

  describe 'test_logger_level_sync_between_solarwinds_apm_and_opentelemetry' do
    # if OTEL_LOG_LEVEL is not set, then opentelemetry logger level should be same as solarwinds apm
    # if not provide logger, then opentelemetry will use default logger, otherwise, it will use forward_logger
    # when define OpenTelemetry.logger = ::Logger.new($stdout, level: 1000), it will overwrite the forward_logger
    before do
      ENV.delete('OTEL_LOG_LEVEL')
      ENV.delete('SW_APM_DEBUG_LEVEL')
      OpenTelemetry.logger = nil
    end

    it 'no_OTEL_LOG_LEVEL_shows_up_SW_APM_DEBUG_LEVEL_3_solarwinds_apm_and_otel_have_same_logger_level' do
      ENV['SW_APM_DEBUG_LEVEL'] = '3'
      SolarWindsAPM::Config.set_log_level
      SolarWindsAPM::OTelConfig.initialize
      _(OpenTelemetry.logger.level).must_equal SolarWindsAPM.logger.level
    end

    it 'no_OTEL_LOG_LEVEL_shows_up_SW_APM_DEBUG_LEVEL_2_solarwinds_apm_and_otel_have_same_logger_level' do
      ENV['SW_APM_DEBUG_LEVEL'] = '2'
      SolarWindsAPM::Config.set_log_level
      SolarWindsAPM::OTelConfig.initialize
      _(OpenTelemetry.logger.level).must_equal SolarWindsAPM.logger.level
    end

    it 'no_OTEL_LOG_LEVEL_shows_up_SW_APM_DEBUG_LEVEL_0_solarwinds_apm_and_otel_have_same_logger_level' do
      ENV['SW_APM_DEBUG_LEVEL'] = '0'
      SolarWindsAPM::Config.set_log_level
      # ::OpenTelemetry.logger = ''
      SolarWindsAPM::OTelConfig.initialize
      _(OpenTelemetry.logger.level).must_equal SolarWindsAPM.logger.level
    end

    # if user set OTEL_LOG_LEVEL, then the logger level will be separated
    it 'OTEL_LOG_LEVEL_shows_up_solarwinds_apm_and_otel_have_different_logger_level' do
      ENV['OTEL_LOG_LEVEL'] = 'fatal'
      ENV['SW_APM_DEBUG_LEVEL'] = '3'
      SolarWindsAPM::Config.set_log_level
      SolarWindsAPM::OTelConfig.initialize
      _(SolarWindsAPM.logger.level).must_equal 1
      _(OpenTelemetry.logger.level).must_equal 4
    end
  end

  describe 'check_if_tag_sql_patch' do
    it 'tag_sql_is_off' do
      ENV['SW_APM_TAG_SQL'] = 'false'
      SolarWindsAPM::Config.initialize
      _(SolarWindsAPM::Config[:tag_sql]).must_equal false

      SolarWindsAPM::OTelConfig.initialize
      assert_nil(defined?(SolarWindsAPM::Patches::SWOMysql2ClientPatch))
      assert_nil(defined?(SolarWindsAPM::Patches::SWOPgConnectionPatch))
      assert_nil(defined?(SolarWindsAPM::Patches::SWOTrilogyClientPatch))

      ENV.delete('SW_APM_TAG_SQL')
    end

    it 'tag_sql_is_on' do
      ENV['SW_APM_TAG_SQL'] = 'true'
      SolarWindsAPM::Config.initialize
      _(SolarWindsAPM::Config[:tag_sql]).must_equal true

      SolarWindsAPM::OTelConfig.initialize
      _(defined?(SolarWindsAPM::Patches::SWOMysql2ClientPatch)).must_equal 'constant'
      _(defined?(SolarWindsAPM::Patches::SWOPgConnectionPatch)).must_equal 'constant'
      _(defined?(SolarWindsAPM::Patches::SWOTrilogyClientPatch)).must_equal 'constant'

      SolarWindsAPM::Patches.send(:remove_const, :SWOMysql2ClientPatch)
      SolarWindsAPM::Patches.send(:remove_const, :SWOPgConnectionPatch)
      SolarWindsAPM::Patches.send(:remove_const, :SWOTrilogyClientPatch)
      ENV.delete('SW_APM_TAG_SQL')
    end
  end
end
