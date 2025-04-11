# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/otlp_endpoint'
require './lib/solarwinds_apm/support/service_key_checker'

def assert_entity_endpoint_nil
  assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil))
  assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil))
  assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil))
end

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/support/otlp_endpoint_test.rb
describe 'OTLP Endpoint Test' do
  before do
    @original_env = ENV.to_h.dup
    ENV.clear
  end

  after do
    ENV.replace(@original_env)
  end

  # 2,5,8 (failed to auth token, not test here)
  describe 'config_token' do
    # 1
    it 'wrong formatted SW_APM_SERVICE_KEY OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com'

      assert_entity_endpoint_nil
    end

    # 3
    it 'correct formatted SW_APM_SERVICE_KEY, auth token set for OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      _(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)).must_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com'

      assert_entity_endpoint_nil
    end

    # 4
    it 'wrong formatted SW_APM_SERVICE_KEY APM PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
      assert_entity_endpoint_nil
    end

    # 6
    it 'correct formatted SW_APM_SERVICE_KEY, auth token set for OTEL PROTO resolved from APM COLLECTOR config' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
      assert_entity_endpoint_nil
    end

    # 7 (when a non-SWO OTLP endpoint is explicitly configured)
    it 'wrong formatted SW_APM_SERVICE_KEY NON-SWO OTLP configured' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://0.0.0.0:4317'

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
      assert_entity_endpoint_nil
    end

    # 9
    it 'correct formatted SW_APM_SERVICE_KEY, no auth token set for NON-SWO OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://0.0.0.0:4317'

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
      assert_entity_endpoint_nil
    end

    # 10 lambda doesn't care about SW_APM_SERVICE_KEY and OTEL_EXPORTER_OTLP_ENDPOINT
    it 'SW_APM_API_TOKEN invalid inside lambda' do
      ENV['SW_APM_API_TOKEN'] = nil
      ENV['LAMBDA_TASK_ROOT'] = '/task/vartask'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
      assert_entity_endpoint_nil
    end

    it 'SW_APM_API_TOKEN valid inside lambda' do
      ENV['SW_APM_API_TOKEN'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      ENV['LAMBDA_TASK_ROOT'] = '/task/vartask'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('METRICS')

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
      assert_entity_endpoint_nil
    end
  end

  describe 'config_endpoint' do
    let(:endpoint_types) { %w[TRACES METRICS LOGS] }

    it 'no OTEL ENDPOINT and no SW_APM_COLLECTOR' do
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

      _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com'
    end

    it 'OTEL ENDPOINT to local and no SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil))

      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://localhost:4317'
      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com'
    end

    it 'OTEL ENDPOINT to otel and with SW_APM_COLLECTOR' do
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-02.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

      _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/traces'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/metrics'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/logs'
      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-02.cloud.solarwinds.com'
    end

    it 'OTEL ENDPOINT to local and with SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://localhost:4317'

      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil))
      assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil))

      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com'
    end

    # 5
    it 'OTEL METRICS ENDPOINT to special and no SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'http://special.host:4317/v1/metrics'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com'
    end

    it 'OTEL METRICS ENDPOINT to special and SW_APM_COLLECTOR to special location' do
      ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'http://special.host:4317/v1/metrics'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs'
      _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.eu-01.cloud.solarwinds.com'
    end

    # 7,8 not appliable since SW_APM_LEGACY will not be present here
  end

  describe 'config_service_name' do
    it 'resource attribute set swo apm service key set' do
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'sw.apm.version=1.1.1,sw.data.module=apm,service.name=otel-autodetected-default'
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my-service'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_service_name

      _(endpoint.instance_variable_get(:@service_name)).must_equal 'otel-autodetected-default'
    end

    it 'otel service name set resource attribute set swo apm service key set' do
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'sw.apm.version=1.1.1,sw.data.module=apm,service.name=otel-autodetected-default'
      ENV['OTEL_SERVICE_NAME'] = 'otel-service-name'
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my-service'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_service_name

      _(endpoint.instance_variable_get(:@service_name)).must_equal 'otel-service-name'
    end

    it 'otel service name set resource attribute set' do
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'sw.apm.version=1.1.1,sw.data.module=apm,service.name=otel-autodetected-default'
      ENV['OTEL_SERVICE_NAME'] = 'otel-service-name'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_service_name

      _(endpoint.instance_variable_get(:@service_name)).must_equal 'otel-service-name'
    end

    it 'inside lambda resource attribute set AWS_LAMBDA_FUNCTION_NAME set' do
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'sw.apm.version=1.1.1,sw.data.module=apm,service.name=otel-autodetected-default'
      ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-lambda-function'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_service_name

      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my-lambda-function'
    end

    it 'inside lambda resource attribute set AWS_LAMBDA_FUNCTION_NAME set otel service name set' do
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'sw.apm.version=1.1.1,sw.data.module=apm,service.name=otel-autodetected-default'
      ENV['OTEL_SERVICE_NAME'] = 'otel-service-name'
      ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-lambda-function'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_service_name

      _(endpoint.instance_variable_get(:@service_name)).must_equal 'otel-service-name'
    end
  end
end
