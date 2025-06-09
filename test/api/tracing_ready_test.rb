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

    @config = {
      collector: 'https://apm.collector.st-ssp.solarwinds.com:443',
      service: 'test-ruby',
      headers: "Bearer #{ENV.fetch('APM_RUBY_TEST_STAGING_KEY', nil)}",
      tracing_mode: true,
      trigger_trace_enabled: true
    }
  end

  after do
    OpenTelemetry::TestHelpers.reset_opentelemetry
    @memory_exporter.reset
  end

  it 'default_test_solarwinds_ready' do
    new_config = @config.dup
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?).must_equal true
  end

  it 'solarwinds_ready_with_5000_wait_time' do
    new_config = @config.dup
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?(5000)).must_equal true
  end

  it 'solarwinds_ready_with_invalid_collector' do
    new_config = @config.merge(collector: URI('https://collector.invalid'))
    sampler = SolarWindsAPM::HttpSampler.new(new_config)
    replace_sampler(sampler)
    _(SolarWindsAPM::API.solarwinds_ready?(100_000)).must_equal false
  end
end
