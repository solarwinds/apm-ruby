# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/otlp_endpoint'
require './lib/solarwinds_apm/support/service_key_checker'

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/support/otlp_endpoint_test.rb -n /xuan/
describe 'OTLP Endpoint Test' do
  before do
    @original_env = ENV.to_h.dup
    ENV.clear
  end

  after do
    ENV.replace(@original_env)
  end

  describe 'config_token' do
    # 1
    it 'wrong formatted SW_APM_SERVICE_KEY OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
    end

    # 2
    it 'correct formatted SW_APM_SERVICE_KEY, but fail auth token OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      _(ENV['OTEL_EXPORTER_OTLP_HEADERS']).must_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
    end

    # 3
    it 'correct formatted SW_APM_SERVICE_KEY, successful auth token OTEL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      _(ENV['OTEL_EXPORTER_OTLP_HEADERS']).must_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
    end

    # 4
    it 'wrong formatted SW_APM_SERVICE_KEY APM PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
    end

    # 5
    it 'wrong formatted SW_APM_SERVICE_KEY with wrong formatted token APM PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
    end

    # 6
    it 'correct formatted SW_APM_SERVICE_KEY, successful auth token APM PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      _(endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      _(endpoint.instance_variable_get(:@service_name)).must_equal 'my_service'
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
    end

    # 7 (for local testing and lambda collector extension)
    it 'wrong formatted SW_APM_SERVICE_KEY LOCAL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = nil
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      assert_nil(ENV['OTEL_EXPORTER_OTLP_HEADERS'])
    end

    # 8
    it 'correct formatted SW_APM_SERVICE_KEY, but fail auth token LOCAL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      assert_nil(ENV['OTEL_EXPORTER_OTLP_HEADERS'])
    end

    # 9
    it 'correct formatted SW_APM_SERVICE_KEY, successful auth token LOCAL PROTO' do
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal true
      assert_nil(ENV['OTEL_EXPORTER_OTLP_HEADERS'])
    end

    # 10 lambda doesn't care about SW_APM_SERVICE_KEY and OTEL_EXPORTER_OTLP_ENDPOINT
    it 'SW_APM_API_TOKEN invalid inside lambda' do
      ENV['SW_APM_API_TOKEN'] = nil
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
      assert_nil(ENV['OTEL_EXPORTER_OTLP_HEADERS'])
    end

    it 'SW_APM_API_TOKEN valid inside lambda' do
      ENV['SW_APM_API_TOKEN'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token

      assert_nil(endpoint.instance_variable_get(:@token))
      assert_nil(endpoint.instance_variable_get(:@service_name))
      _(endpoint.instance_variable_get(:@agent_enable)).must_equal false
      assert_nil(ENV['OTEL_EXPORTER_OTLP_HEADERS'])
    end
  end

  describe 'config_endpoint xuan' do
    let(:endpoint_types) { ['TRACES','METRICS', 'LOGS'] }

    it 'no OTEL ENDPOINT and no SW_APM_COLLECTOR' do
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      assert_nil(ENV['OTEL_EXPORTER_OTLP_ENDPOINT'])
      _(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT']).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics'
      _(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT']).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
    end

    it 'OTEL ENDPOINT to local and no SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV['OTEL_EXPORTER_OTLP_ENDPOINT']).must_equal 'http://localhost:4317'
      assert_nil(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'])
      assert_nil(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'])
      assert_nil(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'])
    end

    it 'OTEL ENDPOINT to otel and with SW_APM_COLLECTOR' do
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-02.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      assert_nil(ENV['OTEL_EXPORTER_OTLP_ENDPOINT'])
      _(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/traces'
      _(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT']).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/metrics'
      _(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT']).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/logs'
    end

    it 'OTEL ENDPOINT to local and no SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV['OTEL_EXPORTER_OTLP_ENDPOINT']).must_equal 'http://localhost:4317'
      assert_nil(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'])
      assert_nil(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'])
      assert_nil(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'])
    end

    # 5
    it 'OTEL METRICS ENDPOINT to special and no SW_APM_COLLECTOR' do
      ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT']).must_equal 'http://special.host:4317/v1/metrics'
      _(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT']).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
      _(ENV['SW_APM_COLLECTOR']).must_equal 'apm.collector.na-01.cloud.solarwinds.com'
    end

    it 'OTEL METRICS ENDPOINT to special and SW_APM_COLLECTOR to special location xuan2' do
      ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint_types.each { |data_type| endpoint.configure_otlp_endpoint(data_type) }

      _(ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT']).must_equal 'http://special.host:4317/v1/metrics'
      _(ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces'
      _(ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT']).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs'
      _(ENV['SW_APM_COLLECTOR']).must_equal 'apm.collector.eu-01.cloud.solarwinds.com'
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
      ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my-service'
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


