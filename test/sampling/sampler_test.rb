# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/sampler_test.rb
require 'minitest_helper'
require './lib/solarwinds_apm/sampling'
require './lib/solarwinds_apm/opentelemetry/solarwinds_propagator'
require './lib/solarwinds_apm/support/transaction_settings'
require './lib/solarwinds_apm/config'
require 'sampling_test_helper'

describe 'SamplerTest' do
  describe 'httpSpanMetadata.name' do
    before do
      @sampler = TestSampler.new({ local_settings: {} })
    end

    it 'handles non-http spans properly' do
      span = {
        kind: OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: { ATTR_NETWORK_TRANSPORT => 'udp' }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({ http: false }, output)
    end

    it 'handles http client spans properly' do
      span = {
        kind: OpenTelemetry::Trace::SpanKind::CLIENT,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => 'GET',
          ATTR_HTTP_RESPONSE_STATUS_CODE => 200,
          ATTR_SERVER_ADDRESS => 'solarwinds.com',
          ATTR_URL_SCHEME => 'https',
          ATTR_URL_PATH => ''
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({ http: false }, output)
    end

    it 'handles http server spans properly' do
      span = {
        kind: OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => 'GET',
          ATTR_HTTP_RESPONSE_STATUS_CODE => 200,
          ATTR_SERVER_ADDRESS => 'solarwinds.com',
          ATTR_URL_SCHEME => 'https',
          ATTR_URL_PATH => ''
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({
                     http: true,
                     method: 'GET',
                     status: 200,
                     scheme: 'https',
                     hostname: 'solarwinds.com',
                     path: '',
                     url: 'https://solarwinds.com'
                   }, output)
    end

    it 'handles legacy http server spans properly' do
      span = {
        kind: OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_METHOD => 'GET',
          ATTR_HTTP_STATUS_CODE => '200',
          ATTR_HTTP_SCHEME => 'https',
          ATTR_NET_HOST_NAME => 'solarwinds.com',
          ATTR_HTTP_TARGET => ''
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({
                     http: true,
                     method: 'GET',
                     status: 200,
                     scheme: 'https',
                     hostname: 'solarwinds.com',
                     path: '',
                     url: 'https://solarwinds.com'
                   }, output)
    end
  end

  describe 'parseSettings.name' do
    before do
      @sampler = TestSampler.new({ local_settings: {} })
    end

    it 'correctly parses JSON settings' do
      timestamp = Time.now.to_i

      json = {
        'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE',
        'value' => 500_000,
        'arguments' => {
          'BucketCapacity' => 0.2,
          'BucketRate' => 0.1,
          'TriggerRelaxedBucketCapacity' => 20,
          'TriggerRelaxedBucketRate' => 10,
          'TriggerStrictBucketCapacity' => 2,
          'TriggerStrictBucketRate' => 1,
          'SignatureKey' => 'key'
        },
        'timestamp' => timestamp,
        'ttl' => 120,
        'warning' => 'warning'
      }

      setting = @sampler.parse_settings(json)

      expected_output = {
        sample_rate: 500_000,
        sample_source: SolarWindsAPM::SampleSource::REMOTE,
        flags: SolarWindsAPM::Flags::SAMPLE_START |
               SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS |
               SolarWindsAPM::Flags::TRIGGERED_TRACE |
               SolarWindsAPM::Flags::OVERRIDE,
        buckets: {
          SolarWindsAPM::BucketType::DEFAULT => {
            capacity: 0.2,
            rate: 0.1
          },
          SolarWindsAPM::BucketType::TRIGGER_RELAXED => {
            capacity: 20,
            rate: 10
          },
          SolarWindsAPM::BucketType::TRIGGER_STRICT => {
            capacity: 2,
            rate: 1
          }
        },
        signature_key: 'key',
        timestamp: timestamp,
        ttl: 120,
        warning: 'warning'
      }

      assert_equal expected_output, setting
    end
  end

  def settings(enabled: nil, signature_key: nil)
    {
      'value' => 1_000_000,
      'flags' => enabled ? 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE' : '',
      'arguments' => {
        'BucketCapacity' => 10,
        'BucketRate' => 1,
        'TriggerRelaxedBucketCapacity' => 100,
        'TriggerRelaxedBucketRate' => 10,
        'TriggerStrictBucketCapacity' => 1,
        'TriggerStrictBucketRate' => 0.1,
        'SignatureKey' => signature_key&.force_encoding('UTF-8')
      },
      'timestamp' => Time.now.to_i,
      'ttl' => 60
    }
  end

  def local_settings(trigger_trace: nil, tracing_mode: nil, transaction_settings: nil)
    {
      tracing_mode: tracing_mode,
      trigger_trace_enabled: trigger_trace,
      transaction_settings: transaction_settings
    }
  end

  def replace_sampler(sampler)
    OpenTelemetry.tracer_provider.sampler = OpenTelemetry::SDK::Trace::Samplers.parent_based(
      root: sampler,
      remote_parent_sampled: sampler,
      remote_parent_not_sampled: sampler
    )
  end

  describe 'Sampler.name' do
    let(:tracer) { OpenTelemetry.tracer_provider.tracer('test') }

    before do
      ENV['OTEL_TRACES_EXPORTER'] = 'none'
      OpenTelemetry::SDK.configure
      @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      OpenTelemetry.tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))
    end

    after do
      OpenTelemetry::TestHelpers.reset_opentelemetry
      @memory_exporter.reset
    end

    it 'respects enabled settings when no config or transaction settings' do
      sampler = TestSampler.new({ local_settings: local_settings(trigger_trace: false), settings: settings(enabled: true) })
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'respects disabled settings when no config or transaction settings' do
      sampler = TestSampler.new({ local_settings: local_settings(trigger_trace: false), settings: settings(enabled: false) })

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it 'respects enabled config when no transaction settings' do
      sampler = TestSampler.new({ local_settings: local_settings(trigger_trace: true, tracing_mode: true), settings: settings(enabled: false) })

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'respects disabled config when no transaction settings' do
      sampler = TestSampler.new({ local_settings: local_settings(trigger_trace: false, tracing_mode: false) })

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it 'respects enabled matching transaction setting' do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(trigger_trace: false, tracing_mode: false, transaction_settings: [
                                           { tracing: true, matcher: -> { true } }
                                         ]),
          settings: settings(enabled: false)
        }
      )

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'respects disabled matching transaction setting' do
      sampler = TestSampler.new({ local_settings: local_settings(trigger_trace: true, tracing_mode: true, transaction_settings: [{ tracing: false, matcher: -> { true } }]) })

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it 'respects first matching transaction setting' do
      sampler = TestSampler.new(
        { local_settings: local_settings(trigger_trace: false, tracing_mode: false, transaction_settings: [
                                           { tracing: true, matcher: -> { true } },
                                           { tracing: false, matcher: -> { true } }
                                         ]),
          settings: settings(enabled: false) }
      )

      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        _(span.recording?).must_equal true
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'matches non-http spans properly' do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
                                           { tracing: true, matcher: ->(name) { name == 'CLIENT:test' } }
                                         ]),
          settings: settings(enabled: false)
        }
      )

      replace_sampler(sampler)

      tracer.in_span('test', kind: OpenTelemetry::Trace::SpanKind::CLIENT) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'matches http spans properly' do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
                                           { tracing: true, matcher: ->(name) { name == 'http://localhost/test' } }
                                         ]),
          settings: settings(enabled: false)
        }
      )

      replace_sampler(sampler)

      tracer.in_span(
        'test',
        kind: OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => 'GET',
          ATTR_URL_SCHEME => 'http',
          ATTR_SERVER_ADDRESS => 'localhost',
          ATTR_URL_PATH => '/test'
        }
      ) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        ATTR_HTTP_REQUEST_METHOD => 'GET',
        ATTR_URL_SCHEME => 'http',
        ATTR_SERVER_ADDRESS => 'localhost',
        ATTR_URL_PATH => '/test',
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'matches deprecated http spans properly' do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
                                           { tracing: true, matcher: ->(name) { name == 'http://localhost/test' } }
                                         ]),
          settings: settings(enabled: false)
        }
      )

      replace_sampler(sampler)

      tracer.in_span(
        'test',
        kind: OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_METHOD => 'GET',
          ATTR_HTTP_SCHEME => 'http',
          ATTR_NET_HOST_NAME => 'localhost',
          ATTR_HTTP_TARGET => '/test'
        }
      ) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        ATTR_HTTP_METHOD => 'GET',
        ATTR_HTTP_SCHEME => 'http',
        ATTR_NET_HOST_NAME => 'localhost',
        ATTR_HTTP_TARGET => '/test',
        'SampleRate' => 1_000_000,
        'SampleSource' => 6,
        'BucketCapacity' => 10,
        'BucketRate' => 1
      }
    end

    it 'picks up trigger-trace' do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(trigger_trace: true),
          settings: settings(enabled: true)
        }
      )

      replace_sampler(sampler)

      ctx = OpenTelemetry::Context.new({
                                         'sw_xtraceoptions' => 'trigger-trace'
                                       })

      OpenTelemetry::Context.with_current(ctx) do
        tracer.in_span('test') do |span|
          assert span.recording?
        end
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      _(spans[0].attributes['BucketCapacity']).must_equal 1
      _(spans[0].attributes['BucketRate']).must_equal 0.1
    end
  end

  describe 'parse_settings' do
    before do
      @sampler = TestSampler.new({ local_settings: {} })
    end

    it 'returns nil for non-hash input' do
      assert_nil @sampler.parse_settings('not a hash')
      assert_nil @sampler.parse_settings(nil)
      assert_nil @sampler.parse_settings(42)
    end

    it 'returns nil for missing numeric fields' do
      assert_nil @sampler.parse_settings({ 'value' => 'not_a_number', 'timestamp' => 1, 'ttl' => 1, 'flags' => 'SAMPLE_START' })
      assert_nil @sampler.parse_settings({ 'value' => 1, 'timestamp' => 'bad', 'ttl' => 1, 'flags' => 'SAMPLE_START' })
      assert_nil @sampler.parse_settings({ 'value' => 1, 'timestamp' => 1, 'ttl' => 'bad', 'flags' => 'SAMPLE_START' })
    end

    it 'returns nil for non-string flags' do
      assert_nil @sampler.parse_settings({ 'value' => 1, 'timestamp' => 1, 'ttl' => 1, 'flags' => 123 })
    end

    it 'handles unknown flags gracefully' do
      result = @sampler.parse_settings({ 'value' => 1, 'timestamp' => 1, 'ttl' => 1, 'flags' => 'UNKNOWN_FLAG' })
      refute_nil result
      assert_equal SolarWindsAPM::Flags::OK, result[:flags]
    end

    it 'handles empty arguments hash' do
      result = @sampler.parse_settings({
                                         'value' => 1,
                                         'timestamp' => 1,
                                         'ttl' => 1,
                                         'flags' => 'SAMPLE_START',
                                         'arguments' => {}
                                       })
      refute_nil result
      assert_empty result[:buckets]
      assert_nil result[:signature_key]
    end

    it 'handles non-hash arguments' do
      result = @sampler.parse_settings({
                                         'value' => 1,
                                         'timestamp' => 1,
                                         'ttl' => 1,
                                         'flags' => 'SAMPLE_START',
                                         'arguments' => 'not_a_hash'
                                       })
      refute_nil result
      assert_empty result[:buckets]
    end

    it 'parses settings without warning' do
      result = @sampler.parse_settings({
                                         'value' => 1,
                                         'timestamp' => 1,
                                         'ttl' => 1,
                                         'flags' => 'SAMPLE_START'
                                       })
      refute_nil result
      assert_nil result[:warning]
    end
  end

  describe 'update_settings' do
    before do
      @sampler = TestSampler.new({ local_settings: {} })
    end

    it 'updates with valid settings and returns parsed' do
      result = @sampler.update_settings({
                                          'value' => 500_000,
                                          'timestamp' => Time.now.to_i,
                                          'ttl' => 120,
                                          'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS'
                                        })
      refute_nil result
      assert_equal 500_000, result[:sample_rate]
    end

    it 'returns nil for invalid settings' do
      result = @sampler.update_settings('invalid')
      assert_nil result
    end

    it 'updates with warning from parsed settings' do
      result = @sampler.update_settings({
                                          'value' => 1,
                                          'timestamp' => Time.now.to_i,
                                          'ttl' => 120,
                                          'flags' => 'SAMPLE_START',
                                          'warning' => 'Some warning'
                                        })
      refute_nil result
      assert_equal 'Some warning', result[:warning]
    end
  end

  describe 'resolve_tracing_mode' do
    it 'returns ALWAYS when tracing_mode is true' do
      sampler = TestSampler.new({ local_settings: { tracing_mode: true } })
      assert_equal SolarWindsAPM::TracingMode::ALWAYS, sampler.instance_variable_get(:@tracing_mode)
    end

    it 'returns NEVER when tracing_mode is false' do
      sampler = TestSampler.new({ local_settings: { tracing_mode: false } })
      assert_equal SolarWindsAPM::TracingMode::NEVER, sampler.instance_variable_get(:@tracing_mode)
    end

    it 'returns nil when tracing_mode not in config' do
      sampler = TestSampler.new({ local_settings: {} })
      assert_nil sampler.instance_variable_get(:@tracing_mode)
    end

    it 'returns nil when tracing_mode is nil' do
      sampler = TestSampler.new({ local_settings: { tracing_mode: nil } })
      assert_nil sampler.instance_variable_get(:@tracing_mode)
    end
  end

  describe 'local_settings with transaction_settings' do
    it 'uses default settings when no transaction_settings configured' do
      sampler = TestSampler.new({ local_settings: { tracing_mode: true } })
      params = make_sample_params
      settings = sampler.local_settings(params)
      assert_equal SolarWindsAPM::TracingMode::ALWAYS, settings[:tracing_mode]
    end

    it 'applies transaction settings filter for http spans' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:transaction_settings] = [
        { regexp: '/health', tracing: :disabled }
      ]

      sampler = TestSampler.new({
                                  local_settings: {
                                    tracing_mode: true,
                                    transaction_settings: SolarWindsAPM::Config[:transaction_settings]
                                  }
                                })

      attrs = {
        'http.request.method' => 'GET',
        'url.scheme' => 'https',
        'server.address' => 'localhost',
        'url.path' => '/health'
      }
      params = make_sample_params(kind: OpenTelemetry::Trace::SpanKind::SERVER)
      params[:attributes] = attrs

      settings = sampler.local_settings(params)
      assert_equal SolarWindsAPM::TracingMode::NEVER, settings[:tracing_mode]
    ensure
      SolarWindsAPM::Config[:transaction_settings] = nil
    end
  end

  describe 'http_span_metadata additional' do
    before do
      @sampler = TestSampler.new({ local_settings: {} })
    end

    it 'uses defaults when attributes are missing' do
      attrs = { 'http.request.method' => 'GET' }
      result = @sampler.http_span_metadata(OpenTelemetry::Trace::SpanKind::SERVER, attrs)
      assert result[:http]
      assert_equal 'http', result[:scheme]
      assert_equal 'localhost', result[:hostname]
      assert_equal 0, result[:status]
    end
  end

  describe 'wait_until_ready' do
    it 'returns false on timeout when no settings' do
      sampler = TestSampler.new({ local_settings: {} })
      result = sampler.wait_until_ready(0.1)
      refute result
    end

    it 'returns true when settings are available with signature_key' do
      sampler = TestSampler.new({
                                  local_settings: {},
                                  settings: {
                                    'value' => 1_000_000,
                                    'timestamp' => Time.now.to_i,
                                    'ttl' => 120,
                                    'flags' => 'SAMPLE_START',
                                    'arguments' => { 'SignatureKey' => 'test-key' }
                                  }
                                })
      result = sampler.wait_until_ready(1)
      assert result
    end
  end

  describe 'request_headers' do
    it 'extracts trace options from parent context' do
      sampler = TestSampler.new({ local_settings: {} })
      context = OpenTelemetry::Context.empty
      context = context.set_value('sw_xtraceoptions', 'trigger-trace;ts=12345')
      context = context.set_value('sw_signature', 'abc123')

      params = { parent_context: context }
      headers = sampler.request_headers(params)

      assert_equal 'trigger-trace;ts=12345', headers['X-Trace-Options']
      assert_equal 'abc123', headers['X-Trace-Options-Signature']
    end

    it 'returns nil values when context has no trace options' do
      sampler = TestSampler.new({ local_settings: {} })
      context = OpenTelemetry::Context.empty
      params = { parent_context: context }
      headers = sampler.request_headers(params)

      assert_nil headers['X-Trace-Options']
      assert_nil headers['X-Trace-Options-Signature']
    end
  end
end
