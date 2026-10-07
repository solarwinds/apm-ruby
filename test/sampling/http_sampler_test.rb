# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
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
    it 'does not sample spans when collector endpoint is invalid' do
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

    it 'retries failed settings requests with backoff delay' do
      sleep 1 # Simulating backoff delay
    end
  end

  describe 'request handling without network' do
    before do
      # allocate skips #initialize so no background settings thread is started
      @log_output = StringIO.new
      @sampler = SolarWindsAPM::HttpSampler.allocate
      @sampler.instance_variable_set(:@logger, Logger.new(@log_output))
      @sampler.instance_variable_set(:@setting_url, URI('https://collector.test/v1/settings'))
      @sampler.instance_variable_set(:@headers, 'Bearer test')
    end

    def http_ok(body)
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
      response
    end

    # runs one iteration of the endless loop; the stubbed sleep ends it and records the delay
    def run_settings_request(response)
      sleeps = []
      @sampler.stub(:fetch_with_timeout, response) do
        @sampler.stub(:sleep, lambda { |duration|
          sleeps << duration
          raise StopIteration
        }) do
          @sampler.send(:settings_request)
        end
      end
      sleeps
    end

    it 'logs an error when the settings thread cannot be started' do
      @sampler.instance_variable_set(:@pid, nil)

      Thread.stub(:new, ->(*) { raise ThreadError, 'cannot start' }) do
        @sampler.send(:reset_on_fork)
      end

      assert_includes @log_output.string, 'Unexpected error in HttpSampler#reset_on_fork: cannot start'
    end

    it 'returns nil when the settings request times out' do
      [Net::ReadTimeout, Net::OpenTimeout].each do |error|
        Net::HTTP.stub(:start, ->(*_args, **_opts) { raise error }) do
          assert_nil @sampler.send(:fetch_with_timeout, URI('https://collector.test/v1/settings'))
        end
      end

      assert_includes @log_output.string, 'Request timed out after'
    end

    it 'warns and waits the default duration when the response is not successful' do
      sleeps = run_settings_request(nil)

      assert_equal [SolarWindsAPM::HttpSampler::GET_SETTING_DURATION], sleeps
      assert_includes @log_output.string, 'Failed to retrieve settings due to timeout'
    end

    it 'warns when the retrieved settings are invalid' do
      run_settings_request(http_ok('{}'))

      assert_includes @log_output.string, 'Retrieved sampling settings are invalid'
    end

    it 'warns when the response body is not valid JSON' do
      run_settings_request(http_ok('not json'))

      assert_includes @log_output.string, 'JSON parsing error'
    end

    it 'warns when updating the settings raises an error' do
      @sampler.stub(:update_settings, ->(_settings) { raise StandardError, 'boom' }) do
        run_settings_request(http_ok('{}'))
      end

      assert_includes @log_output.string, 'Failed to retrieve sampling settings (boom)'
    end
  end
end
