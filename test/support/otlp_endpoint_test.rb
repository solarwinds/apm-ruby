# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/otlp_endpoint'
require './lib/solarwinds_apm/support/service_key_checker'
require './lib/solarwinds_apm/support/utils'

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/support/otlp_endpoint_test.rb
OTLP_TEST_TOKEN = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
OTLP_TEST_SERVICE_KEY = "#{OTLP_TEST_TOKEN}:my_service".freeze

describe 'OTLP Endpoint Test' do
  before do
    @original_env = ENV.to_h.dup
    ENV.clear
  end

  after do
    ENV.replace(@original_env)
  end

  def _setup
    @endpoint = SolarWindsAPM::OTLPEndPoint.new
    @endpoint.config_otlp_token_and_endpoint
  end

  def assert_signal_endpoint_nil
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil))
  end

  def assert_signal_endpoint_default
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
  end

  def assert_signal_headers_bearer(*signals)
    signals.each do |signal|
      assert_equal "authorization=Bearer #{OTLP_TEST_TOKEN}", ENV.fetch("OTEL_EXPORTER_OTLP_#{signal}_HEADERS", nil)
    end
  end

  def assert_no_bearer_anywhere
    %w[OTEL_EXPORTER_OTLP_HEADERS OTEL_EXPORTER_OTLP_TRACES_HEADERS OTEL_EXPORTER_OTLP_METRICS_HEADERS OTEL_EXPORTER_OTLP_LOGS_HEADERS].each do |name|
      refute_includes ENV.fetch(name, '').to_s, OTLP_TEST_TOKEN, "#{name} must not carry the service key token"
    end
  end

  def assert_singal_headers_nil(general_singal_header: true)
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_HEADERS', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)) if general_singal_header
  end

  it 'wrong formatted SW_APM_SERVICE_KEY NON-SWO OTLP configured' do
    ENV['SW_APM_SERVICE_KEY'] = nil
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'

    _setup

    assert_nil(@endpoint.instance_variable_get(:@token))

    assert_equal 'http://0.0.0.0:4317', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY, no auth token set for NON-SWO OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'

    _setup

    assert_equal OTLP_TEST_TOKEN, @endpoint.instance_variable_get(:@token)
    assert_equal 'http://0.0.0.0:4317', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)

    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY with headers set' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_METRICS_HEADERS'] = 'authorization=Bearer bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'authorization=Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

    _setup

    assert_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234', @endpoint.instance_variable_get(:@token)
    assert_equal 'authorization=Bearer bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_HEADERS', nil))
    assert_equal 'authorization=Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)

    assert_signal_endpoint_default
  end

  it 'wrong formatted SW_APM_SERVICE_KEY OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = nil
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_nil(@endpoint.instance_variable_get(:@token))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))

    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)

    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY, auth token set for OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234', @endpoint.instance_variable_get(:@token)

    assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
    assert_signal_headers_bearer('TRACES', 'METRICS', 'LOGS')
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)

    assert_signal_endpoint_nil
  end

  it 'wrong formatted SW_APM_SERVICE_KEY APM PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = nil
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_nil(@endpoint.instance_variable_get(:@token))

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
    assert_signal_endpoint_default
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY APM PROTO, auth token set on derived SWO signal endpoints' do
    ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_equal OTLP_TEST_TOKEN, @endpoint.instance_variable_get(:@token)

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
    assert_signal_endpoint_default
    assert_signal_headers_bearer('TRACES', 'METRICS', 'LOGS')
  end

  it 'no OTEL ENDPOINT and no SW_APM_COLLECTOR' do
    _setup

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
  end

  it 'OTEL ENDPOINT to local and no SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'

    _setup

    assert_equal 'http://localhost:4317', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)
    assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)

    assert_signal_endpoint_nil
  end

  it 'OTEL ENDPOINT to otel and with SW_APM_COLLECTOR' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-02.cloud.solarwinds.com:443'

    _setup

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

    assert_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.na-02.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
  end

  it 'OTEL ENDPOINT to local and with SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_equal 'http://localhost:4317', ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)
    assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)

    assert_signal_endpoint_nil
  end

  # 5
  it 'OTEL METRICS ENDPOINT to special and no SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'

    _setup

    assert_equal 'http://special.host:4317/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
  end

  it 'OTEL METRICS ENDPOINT to special and SW_APM_COLLECTOR to special location' do
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com:443'

    _setup

    assert_equal 'http://special.host:4317/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.eu-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
  end

  it 'OTLP endpoint without port' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com/v1/metrics'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'

    _setup

    assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.eu-01.cloud.solarwinds.com', ENV.fetch('SW_APM_COLLECTOR', nil)

    assert_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)
  end

  it 'swo endpoint without port' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'

    _setup

    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    assert_equal 'apm.collector.eu-01.cloud.solarwinds.com', ENV.fetch('SW_APM_COLLECTOR', nil)
  end

  it 'swo endpoint without port but in wrong format fallback to default' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds'

    _setup

    assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
    assert_signal_endpoint_default
  end

  describe 'initialize' do
    it 'initializes with nil token and service_name' do
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      assert_nil endpoint.token
      assert_nil endpoint.service_name
    end
  end

  describe 'resolve_get_setting_endpoint' do
    it 'keeps valid collector endpoint' do
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      matches = ENV['SW_APM_COLLECTOR'].match(SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_REGEX)
      endpoint.send(:resolve_get_setting_endpoint, matches)
      assert_equal 'apm.collector.na-01.cloud.solarwinds.com:443', ENV.fetch('SW_APM_COLLECTOR', nil)
    end

    it 'falls back to default for invalid collector' do
      ENV['SW_APM_COLLECTOR'] = 'invalid-endpoint'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      matches = ENV['SW_APM_COLLECTOR'].match(SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_REGEX)
      endpoint.send(:resolve_get_setting_endpoint, matches)
      assert_equal SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_DEFAULT, ENV.fetch('SW_APM_COLLECTOR', nil)
    end

    it 'falls back to default for empty collector' do
      ENV.delete('SW_APM_COLLECTOR')
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.send(:resolve_get_setting_endpoint, nil)
      assert_equal SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_DEFAULT, ENV.fetch('SW_APM_COLLECTOR', nil)
    end
  end

  describe 'configure_otlp_endpoint' do
    it 'sets endpoint from matched collector when no existing endpoint' do
      ENV.delete('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT')
      ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      matches = 'apm.collector.eu-01.cloud.solarwinds.com:443'.match(SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_REGEX)

      endpoint.configure_otlp_endpoint('TRACES', matches)
      assert_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    end

    it 'sets default endpoint when no matches and no endpoint' do
      ENV.delete('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT')
      ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.configure_otlp_endpoint('METRICS', nil)
      assert_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics', ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)
    end

    it 'does not override existing signal endpoint' do
      ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'] = 'https://custom.endpoint/v1/logs'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.configure_otlp_endpoint('LOGS', nil)
      assert_equal 'https://custom.endpoint/v1/logs', ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)
    end

    it 'does not override when general endpoint is set' do
      ENV.delete('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT')
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://custom.general/endpoint'
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.configure_otlp_endpoint('TRACES', nil)
      refute_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)
    end
  end

  describe 'config_token' do
    it 'sets token on signal headers (not general) when general endpoint is SWO' do
      ENV.delete('OTEL_EXPORTER_OTLP_HEADERS')
      ENV.delete('OTEL_EXPORTER_OTLP_TRACES_HEADERS')
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_equal 'authorization=Bearer my-token', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end

    it 'sets token on signal headers when signal endpoint matches' do
      ENV.delete('OTEL_EXPORTER_OTLP_HEADERS')
      ENV.delete('OTEL_EXPORTER_OTLP_TRACES_HEADERS')
      ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_equal 'authorization=Bearer my-token', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end

    it 'does not set token when no token available' do
      ENV.delete('OTEL_EXPORTER_OTLP_HEADERS')
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.config_token('TRACES')
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
    end

    it 'does not override existing headers' do
      ENV['OTEL_EXPORTER_OTLP_TRACES_HEADERS'] = 'existing=header'
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_equal 'existing=header', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end

    it 'does not set a fallback token when no endpoint is configured' do
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end

    it 'does not set token when signal endpoint is non-SWO' do
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://collector.internal:4318/v1/traces'

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end

    it 'does not add signal token when user set general headers' do
      ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'x-custom=1'
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'

      endpoint = SolarWindsAPM::OTLPEndPoint.new
      endpoint.instance_variable_set(:@token, 'my-token')
      endpoint.config_token('TRACES')

      assert_equal 'x-custom=1', ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
    end
  end

  # Regression tests: the service key must never be sent to a non-SolarWinds OTLP endpoint
  describe 'service key is not sent to non-SWO endpoints' do
    it 'custom http traces endpoint gets no bearer, other signals use SWO with bearer' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://my-collector:4318/v1/traces'

      _setup

      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
      assert_signal_headers_bearer('METRICS', 'LOGS')
    end

    it 'custom https general endpoint gets no bearer for any signal' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://collector.example.com:4318'

      _setup

      assert_no_bearer_anywhere
      assert_signal_endpoint_nil
    end

    it 'general SWO endpoint with custom metrics endpoint does not leak bearer to metrics' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'
      ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://my-collector:4318/v1/metrics'

      _setup

      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_nil ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)
      assert_signal_headers_bearer('TRACES', 'LOGS')
    end

    it 'user trace header with custom metrics/logs endpoints does not install a global bearer' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['OTEL_EXPORTER_OTLP_TRACES_HEADERS'] = 'x-lab=control'
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://my-collector:4318'

      _setup

      assert_equal 'x-lab=control', ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil)
      assert_no_bearer_anywhere
    end

    it 'user supplied headers are preserved for custom collector forwarding to SWO' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://my-collector:4318'
      ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "authorization=Bearer #{OTLP_TEST_TOKEN}"

      _setup

      assert_equal "authorization=Bearer #{OTLP_TEST_TOKEN}", ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)
      assert_singal_headers_nil(general_singal_header: false)
    end

    it 'no service key sets no headers with custom endpoint' do
      ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://my-collector:4318/v1/traces'

      _setup

      assert_singal_headers_nil
    end

    it 'SW_APM_COLLECTOR with userinfo/path trick falls back to default SWO collector' do
      ENV['SW_APM_SERVICE_KEY'] = OTLP_TEST_SERVICE_KEY
      ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.foo@localhost:1234/.solarwinds.com'

      _setup

      assert_equal SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_DEFAULT, ENV.fetch('SW_APM_COLLECTOR', nil)
      assert_signal_endpoint_default
      assert_signal_headers_bearer('TRACES', 'METRICS', 'LOGS')
    end

    it 'SW_APM_COLLECTOR with embedded newline falls back to default SWO collector' do
      ENV['SW_APM_COLLECTOR'] = "evil.example.com\napm.collector.na-01.cloud.solarwinds.com"

      _setup

      assert_equal SolarWindsAPM::OTLPEndPoint::SWO_APM_ENDPOINT_DEFAULT, ENV.fetch('SW_APM_COLLECTOR', nil)
    end
  end

  describe 'sanitize_endpoint' do
    it 'drops userinfo, path and query' do
      endpoint = SolarWindsAPM::OTLPEndPoint.new
      assert_equal 'http://collector:4318', endpoint.sanitize_endpoint('http://user:secret@collector:4318/v1/traces?token=x')
      assert_equal '<unparseable>', endpoint.sanitize_endpoint('not a url')
      assert_equal '<unparseable>', endpoint.sanitize_endpoint(nil)
    end
  end

  describe 'swo_otlp_endpoint?' do
    before { @endpoint = SolarWindsAPM::OTLPEndPoint.new }

    [
      'https://otel.collector.na-01.cloud.solarwinds.com:443',
      'https://otel.collector.na-01.cloud.solarwinds.com',
      'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces',
      'https://OTEL.collector.na-01.cloud.solarwinds.com/v1/metrics'
    ].each do |url|
      it "accepts #{url}" do
        assert @endpoint.swo_otlp_endpoint?(url)
      end
    end

    [
      nil,
      '',
      'http://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces',
      'https://otel.collector.na-01.cloud.solarwinds.com.evil.example/v1/traces',
      'https://otel.collector.na-01.cloud.solarwinds.com@evil.example/v1/traces',
      'https://user@otel.collector.na-01.cloud.solarwinds.com/v1/traces',
      'https://evil.example/otel.collector.na-01.cloud.solarwinds.com',
      "https://evil.example\nhttps://otel.collector.na-01.cloud.solarwinds.com",
      'https://collector.example.com:4318',
      'not a url'
    ].each do |url|
      it "rejects #{url.inspect}" do
        refute @endpoint.swo_otlp_endpoint?(url)
      end
    end
  end
end
