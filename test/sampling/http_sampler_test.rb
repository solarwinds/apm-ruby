# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling'
require 'sampling_test_helper'

describe 'HttpSampler' do
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

  describe 'valid service key' do
    it 'samples created spans' do
      new_config = @config.dup
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span('test') do |span|
        assert span.recording?
      end

      span = @memory_exporter.finished_spans[0]

      refute_nil span
      assert_equal span.attributes.keys, %w[SampleRate SampleSource BucketCapacity BucketRate]
    end
  end

  describe 'invalid service key' do
    it 'does not sample created spans' do
      new_config = @config.merge(headers: 'Bearer oh-no')
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span('test') do |span|
        refute span.recording?
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end
  end

  describe 'invalid collector' do
    it 'does not sample created spans xuan' do
      new_config = @config.merge(collector: URI('https://collector.invalid'))
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span('test') do |span|
        refute span.recording?
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end

    it 'retries with backoff' do
      sleep 1 # Simulating backoff delay
    end
  end
end
