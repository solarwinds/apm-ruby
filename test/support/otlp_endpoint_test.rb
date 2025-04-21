# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/otlp_endpoint'
require './lib/solarwinds_apm/support/service_key_checker'
require './lib/solarwinds_apm/support/utils'

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/support/otlp_endpoint_test.rb
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
    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
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

    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://0.0.0.0:4317'

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY, no auth token set for NON-SWO OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://0.0.0.0:4317'

    _setup

    _(@endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://0.0.0.0:4317'

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))
    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY with headers set' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_METRICS_HEADERS'] = 'authorization=Bearer bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'authorization=Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

    _setup

    _(@endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)).must_equal 'authorization=Bearer bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_HEADERS', nil))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_HEADERS', nil))
    _(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)).must_equal 'authorization=Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

    assert_signal_endpoint_default
  end

  it 'wrong formatted SW_APM_SERVICE_KEY OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = nil
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    _setup

    assert_nil(@endpoint.instance_variable_get(:@token))
    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil))

    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    assert_signal_endpoint_nil
    assert_singal_headers_nil
  end

  it 'correct formatted SW_APM_SERVICE_KEY, auth token set for OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    _setup

    _(@endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'

    _(ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil)).must_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443'

    assert_signal_endpoint_nil
    assert_singal_headers_nil(general_singal_header: false)
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

  it 'correct formatted SW_APM_SERVICE_KEY APM PROTO, no auth token set due to no OTEL PROTO' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'

    _setup

    _(@endpoint.instance_variable_get(:@token)).must_equal '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))
    assert_signal_endpoint_default
    assert_singal_headers_nil
  end

  it 'no OTEL ENDPOINT and no SW_APM_COLLECTOR' do
    _setup

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com:443'
  end

  it 'OTEL ENDPOINT to local and no SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://localhost:4317'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com:443'

    assert_signal_endpoint_nil
  end

  it 'OTEL ENDPOINT to otel and with SW_APM_COLLECTOR' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-02.cloud.solarwinds.com:443'

    _setup

    assert_nil(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil))

    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-02.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-02.cloud.solarwinds.com:443'
  end

  it 'OTEL ENDPOINT to local and with SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.na-01.cloud.solarwinds.com:443'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)).must_equal 'http://localhost:4317'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com:443'

    assert_signal_endpoint_nil
  end

  # 5
  it 'OTEL METRICS ENDPOINT to special and no SW_APM_COLLECTOR' do
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'http://special.host:4317/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com:443'
  end

  it 'OTEL METRICS ENDPOINT to special and SW_APM_COLLECTOR to special location' do
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'http://special.host:4317/v1/metrics'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com:443'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'http://special.host:4317/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.eu-01.cloud.solarwinds.com:443'
  end

  it 'OTLP endpoint without port' do
    ENV['SW_APM_SERVICE_KEY'] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'
    ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] = 'https://otel.collector.na-01.cloud.solarwinds.com/v1/metrics'
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.na-01.cloud.solarwinds.com/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.eu-01.cloud.solarwinds.com'

    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_HEADERS', nil)).must_equal 'authorization=Bearer 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234'
  end

  it 'swo endpoint without port' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds.com'

    _setup

    _(ENV.fetch('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/metrics'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/traces'
    _(ENV.fetch('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', nil)).must_equal 'https://otel.collector.eu-01.cloud.solarwinds.com:443/v1/logs'
    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.eu-01.cloud.solarwinds.com'
  end

  it 'swo endpoint without port but in wrong format fallback to default' do
    ENV['SW_APM_COLLECTOR'] = 'apm.collector.eu-01.cloud.solarwinds'

    _setup

    _(ENV.fetch('SW_APM_COLLECTOR', nil)).must_equal 'apm.collector.na-01.cloud.solarwinds.com:443'
    assert_signal_endpoint_default
  end
end
