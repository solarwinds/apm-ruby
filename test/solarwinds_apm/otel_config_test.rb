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

  describe 'test_otlp_metrics_custom_metrics' do
    it 'test_mask_token_with_71' do
      token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      _(SolarWindsAPM::OTelConfig.mask_token(token)).must_equal 'aa*******************************************************************aa'
    end

    it 'test_mask_token_with_2' do
      token = 'aa'
      _(SolarWindsAPM::OTelConfig.mask_token(token)).must_equal '**'
    end

    describe 'test_determine_setup_otlp_metrics' do
      before do
        ENV.delete('SW_APM_EXPORT_METRICS_ENABLED')
        ENV.delete('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT')
        ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
        ENV.delete('SW_APM_COLLECTOR')
      end

      it 'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT_present_ignore_other_options' do
        # ENV['SW_APM_EXPORT_METRICS_ENABLED'] = 'true'
        ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://fake-uri:8181/v1/metrics'
        ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://fake-again-uri:8181'
        ENV['SW_APM_COLLECTOR'] = 'collector.appoptics.com'

        SolarWindsAPM::OTelConfig.determine_otlp_metrics_endpoint

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'http://fake-uri:8181/v1/metrics'
      end

      it 'OTEL_EXPORTER_OTLP_ENDPOINT_present_ignore_other_options' do
        ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://fake-again-uri:8181'
        ENV['SW_APM_COLLECTOR'] = 'collector.appoptics.com'

        SolarWindsAPM::OTelConfig.determine_otlp_metrics_endpoint

        _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://fake-again-uri:8181'
      end

      it 'SW_APM_COLLECTOR_present_with_appoptics' do
        ENV['SW_APM_COLLECTOR'] = 'collector.appoptics.com'

        SolarWindsAPM::OTelConfig.determine_otlp_metrics_endpoint

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal nil
      end

      it 'SW_APM_COLLECTOR_present_with_nil' do
        ENV['SW_APM_COLLECTOR'] = nil

        SolarWindsAPM::OTelConfig.determine_otlp_metrics_endpoint

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.solarwinds.com:443/v1/metrics'
      end

      it 'SW_APM_COLLECTOR_present_with_any_kind_url_will_use_default_endpoint' do
        ENV['SW_APM_COLLECTOR'] = 'apm.so-fake.cloud.solarwinds.com'

        SolarWindsAPM::OTelConfig.determine_otlp_metrics_endpoint

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.solarwinds.com:443/v1/metrics'
      end
    end

    describe 'test_setup_otlp_metrics' do
      before do
        ENV.delete('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT')
        ENV.delete('OTEL_EXPORTER_OTLP_METRICS_HEADERS')
        ENV.delete('OTEL_EXPORTER_OTLP_HEADERS')
        ENV.delete('SW_APM_SERVICE_KEY')
        ENV.delete('OTEL_RESOURCE_ATTRIBUTES')
        ENV.delete('OTEL_SERVICE_NAME')
      end

      it 'SW_APM_SERVICE_KEY_present_without_headers_defined' do
        ENV['SW_APM_SERVICE_KEY'] = 'so_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_key:so_name'

        SolarWindsAPM::OTelConfig.setup_otlp_metrics

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)).must_equal 'authorization=Bearer so_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_key'
        _(ENV.fetch('OTEL_RESOURCE_ATTRIBUTES', nil)).must_equal 'sw.data.module=apm,service.name=so_name'
      end

      it 'SW_APM_SERVICE_KEY_present_with_OTEL_EXPORTER_OTLP_METRICS_HEADERS_defined' do
        ENV['OTEL_EXPORTER_OTLP_METRICS_HEADERS'] = 'sample_fake_headers'
        ENV['SW_APM_SERVICE_KEY'] = 'so_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_key:so_name'

        SolarWindsAPM::OTelConfig.setup_otlp_metrics

        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)).must_equal 'sample_fake_headers'
        _(ENV.fetch('OTEL_RESOURCE_ATTRIBUTES', nil)).must_equal 'sw.data.module=apm,service.name=so_name'
      end

      it 'SW_APM_SERVICE_KEY_present_with_OTEL_EXPORTER_OTLP_HEADERS_defined' do
        ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'sample_fake_again_headers'
        ENV['SW_APM_SERVICE_KEY'] = 'so_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_keyso_key:so_name'

        SolarWindsAPM::OTelConfig.setup_otlp_metrics

        _(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)).must_equal 'sample_fake_again_headers'
        _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)).must_equal nil
        _(ENV.fetch('OTEL_RESOURCE_ATTRIBUTES', nil)).must_equal 'sw.data.module=apm,service.name=so_name'
      end
    end
  end
end
