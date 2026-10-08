# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/sampling'
require 'sampling_test_helper'

describe 'Test solarwinds_ready API call' do
  let(:tracer) { OpenTelemetry.tracer_provider.tracer('test') }
  before do
    ENV['OTEL_TRACES_EXPORTER'] = 'none'
    OpenTelemetry::SDK.configure

    @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry.tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))

    if ENV.key?('APM_RUBY_TEST_STAGING_KEY')
      collector = 'https://apm.collector.st-ssp.solarwinds.com:443'
      headers = ENV['APM_RUBY_TEST_STAGING_KEY']
    else
      collector = 'https://apm.collector.cloud.solarwinds.com:443'
      headers = ENV.fetch('APM_RUBY_TEST_KEY', nil)
    end

    @config = {
      collector: collector,
      service: 'test-ruby',
      headers: "Bearer #{headers}",
      tracing_mode: true,
      trigger_trace_enabled: true
    }
  end

  after do
    OpenTelemetry::TestHelpers.reset_opentelemetry
    @memory_exporter.reset
  end

  it 'returns true with valid default configuration' do
    new_config = @config.dup
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?).must_equal true
  end

  it 'returns true when given a 5000ms wait time' do
    new_config = @config.dup
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?(5000)).must_equal true
  end

  it 'returns false when collector endpoint is invalid' do
    new_config = @config.merge(collector: URI('https://collector.invalid'))
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?(100_000)).must_equal false
  end

  it 'logs a deprecation warning when integer_response is given' do
    root_sampler = Minitest::Mock.new
    root_sampler.expect(:wait_until_ready, true, [0])
    parent_based = Object.new
    parent_based.instance_variable_set(:@root, root_sampler)

    log_output = StringIO.new
    original_logger = SolarWindsAPM.logger
    SolarWindsAPM.logger = Logger.new(log_output)

    OpenTelemetry.tracer_provider.stub(:sampler, parent_based) do
      _(SolarWindsAPM::API.solarwinds_ready?(100, integer_response: true)).must_equal true
    end

    root_sampler.verify
    assert_includes log_output.string, 'solarwinds_ready? no longer accepts integer_response'
  ensure
    SolarWindsAPM.logger = original_logger
  end
end
