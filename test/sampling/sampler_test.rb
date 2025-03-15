# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require 'opentelemetry-test-helpers'
require './lib/solarwinds_apm/sampling'
require './lib/solarwinds_apm/opentelemetry/solarwinds_propagator'
require './lib/solarwinds_apm/support/transaction_settings'
require './lib/solarwinds_apm/config'


class TestSampler < SolarWindsAPM::Sampler
  def initialize(options)
    logger = Logger.new(STDOUT)
    logger.level = ENV['TEST_LOGGER_DEBUG_LEVEL'].nil? ? 6 : ENV['TEST_LOGGER_DEBUG_LEVEL'].to_i
    super(options[:local_settings], logger)
    update_settings(options[:settings]) if options[:settings]
  end
end

describe 'SamplerTest' do
  ATTR_HTTP_REQUEST_METHOD = 'http.request.method'
  ATTR_HTTP_RESPONSE_STATUS_CODE = 'http.response.status_code'
  ATTR_SERVER_ADDRESS = 'server.address'
  ATTR_URL_SCHEME = 'url.scheme'
  ATTR_URL_PATH = 'url.path'
  ATTR_NETWORK_TRANSPORT = 'network.transport'
  ATTR_HTTP_STATUS_CODE = ::OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE
  ATTR_HTTP_METHOD = ::OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD
  ATTR_HTTP_SCHEME = ::OpenTelemetry::SemanticConventions::Trace::HTTP_SCHEME
  ATTR_NET_HOST_NAME = ::OpenTelemetry::SemanticConventions::Trace::NET_HOST_NAME
  ATTR_HTTP_TARGET = ::OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET

  describe 'httpSpanMetadata.name' do
    before do
      @sampler = TestSampler.new({local_settings: {}})
    end

    it "handles non-http spans properly" do
      span = {
        kind: ::OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: { ATTR_NETWORK_TRANSPORT => "udp" }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({ http: false }, output)
    end

    it "handles http client spans properly" do
      span = {
        kind: ::OpenTelemetry::Trace::SpanKind::CLIENT,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => "GET",
          ATTR_HTTP_RESPONSE_STATUS_CODE => 200,
          ATTR_SERVER_ADDRESS => "solarwinds.com",
          ATTR_URL_SCHEME => "https",
          ATTR_URL_PATH => ""
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({ http: false }, output)
    end

    it "handles http server spans properly" do
      span = {
        kind: ::OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => "GET",
          ATTR_HTTP_RESPONSE_STATUS_CODE => 200,
          ATTR_SERVER_ADDRESS => "solarwinds.com",
          ATTR_URL_SCHEME => "https",
          ATTR_URL_PATH => ""
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({
        http: true,
        method: "GET",
        status: 200,
        scheme: "https",
        hostname: "solarwinds.com",
        path: "",
        url: "https://solarwinds.com"
      }, output)
    end

    it "handles legacy http server spans properly" do
      span = {
        kind: ::OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_METHOD => "GET",
          ATTR_HTTP_STATUS_CODE => "200",
          ATTR_HTTP_SCHEME => "https",
          ATTR_NET_HOST_NAME => "solarwinds.com",
          ATTR_HTTP_TARGET => ""
        }
      }

      output = @sampler.http_span_metadata(span[:kind], span[:attributes])
      assert_equal({
        http: true,
        method: "GET",
        status: 200,
        scheme: "https",
        hostname: "solarwinds.com",
        path: "",
        url: "https://solarwinds.com"
      }, output)
    end
  end

  describe 'parseSettings.name' do
    before do
      @sampler = TestSampler.new({local_settings: {}})
    end

    it "correctly parses JSON settings" do
      timestamp = Time.now.to_i

      json = {
        'flags' => "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE",
        'value' => 500_000,
        'arguments' => {
          'BucketCapacity' => 0.2,
          'BucketRate' => 0.1,
          'TriggerRelaxedBucketCapacity' => 20,
          'TriggerRelaxedBucketRate' => 10,
          'TriggerStrictBucketCapacity' => 2,
          'TriggerStrictBucketRate' => 1,
          'SignatureKey' => "key"
        },
        'timestamp' => timestamp,
        'ttl' => 120,
        'warning' => "warning"
      }

      setting = @sampler.parse_settings(json)

      expected_output = {
        sample_rate: 500_000,
        sample_source: SampleSource::REMOTE,
        flags: Flags::SAMPLE_START |
               Flags::SAMPLE_THROUGH_ALWAYS |
               Flags::TRIGGERED_TRACE |
               Flags::OVERRIDE,
        buckets: {
          BucketType::DEFAULT => {
            capacity: 0.2,
            rate: 0.1
          },
          BucketType::TRIGGER_RELAXED => {
            capacity: 20,
            rate: 10
          },
          BucketType::TRIGGER_STRICT => {
            capacity: 2,
            rate: 1
          }
        },
        signature_key: "key",
        timestamp: timestamp,
        ttl: 120,
        warning: "warning"
      }

      assert_equal expected_output, setting
    end
  end

  def settings(enabled: nil, signature_key: nil)
    {
      'value' => 1_000_000,
      'flags' => enabled ? "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE" : "",
      'arguments' => {
        'BucketCapacity' => 10,
        'BucketRate' => 1,
        'TriggerRelaxedBucketCapacity' => 100,
        'TriggerRelaxedBucketRate' => 10,
        'TriggerStrictBucketCapacity' => 1,
        'TriggerStrictBucketRate' => 0.1,
        'SignatureKey' => signature_key&.force_encoding("UTF-8"),
      },
      'timestamp' => Time.now.to_i,
      'ttl' => 60,
    }
  end

  def local_settings(trigger_trace: nil, tracing_mode: nil, transaction_settings: nil)
    {
      tracing_mode: tracing_mode,
      trigger_trace_enabled: trigger_trace,
      transaction_settings: transaction_settings,
    }
  end

  def replace_sampler(sampler)
    ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
      root: sampler,
      remote_parent_sampled: sampler,
      remote_parent_not_sampled: sampler
    )
  end

  describe "Sampler.name" do
    let(:tracer) { ::OpenTelemetry.tracer_provider.tracer("test") }

    before do
      ENV['OTEL_TRACES_EXPORTER'] ='none'
      ::OpenTelemetry::SDK.configure
      @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      ::OpenTelemetry.tracer_provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))
    end

    after do
      OpenTelemetry::TestHelpers.reset_opentelemetry
      @memory_exporter.reset
    end

    it "respects enabled settings when no config or transaction settings" do
      sampler = TestSampler.new({local_settings: local_settings(trigger_trace: false), settings: settings(enabled: true)})
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
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

    it "respects disabled settings when no config or transaction settings" do
      sampler = TestSampler.new({local_settings: local_settings(trigger_trace: false), settings: settings(enabled: false)})

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it "respects enabled config when no transaction settings" do
      sampler = TestSampler.new({local_settings: local_settings(trigger_trace: true, tracing_mode: true), settings: settings(enabled: false)})

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "respects disabled config when no transaction settings" do
      sampler = TestSampler.new({local_settings: local_settings(trigger_trace: false, tracing_mode: false)})

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it "respects enabled matching transaction setting" do
      sampler = TestSampler.new(
        {
          local_settings: local_settings(trigger_trace: false, tracing_mode: false, transaction_settings: [
            { tracing: true, matcher: -> { true } }
          ]),
          settings: settings(enabled: false)
        })

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "respects disabled matching transaction setting" do
      sampler = TestSampler.new({local_settings: local_settings(trigger_trace: true, tracing_mode: true, transaction_settings: [{ tracing: false, matcher: -> { true } }])})

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 0, spans.length
    end

    it "respects first matching transaction setting" do
      sampler = TestSampler.new(
        {local_settings: local_settings(trigger_trace: false, tracing_mode: false, transaction_settings: [
          { tracing: true, matcher: -> { true } },
          { tracing: false, matcher: -> { true } }
        ]),
        settings: settings(enabled: false)
      })

      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        _(span.recording?).must_equal true
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "matches non-http spans properly" do
      sampler = TestSampler.new(
      {
        local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
          { tracing: true, matcher: ->(name) { name == "CLIENT:test" } }
        ]),
        settings: settings(enabled: false)
      })

      replace_sampler(sampler)

      tracer.in_span("test", kind: ::OpenTelemetry::Trace::SpanKind::CLIENT) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "matches http spans properly" do
      sampler = TestSampler.new(
      {
        local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
          { tracing: true, matcher: ->(name) { name == "http://localhost/test" } }
        ]),
        settings: settings(enabled: false)
      })

      replace_sampler(sampler)

      tracer.in_span(
        "test",
        kind: ::OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_REQUEST_METHOD => "GET",
          ATTR_URL_SCHEME => "http",
          ATTR_SERVER_ADDRESS => "localhost",
          ATTR_URL_PATH => "/test"
        }
      ) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        ATTR_HTTP_REQUEST_METHOD => "GET",
        ATTR_URL_SCHEME => "http",
        ATTR_SERVER_ADDRESS => "localhost",
        ATTR_URL_PATH => "/test",
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "matches deprecated http spans properly" do
      sampler = TestSampler.new(
      {
        local_settings: local_settings(tracing_mode: false, trigger_trace: false, transaction_settings: [
          { tracing: true, matcher: ->(name) { name == "http://localhost/test" } }
        ]),
        settings: settings(enabled: false)
      })

      replace_sampler(sampler)

      tracer.in_span(
        "test",
        kind: ::OpenTelemetry::Trace::SpanKind::SERVER,
        attributes: {
          ATTR_HTTP_METHOD => "GET",
          ATTR_HTTP_SCHEME => "http",
          ATTR_NET_HOST_NAME => "localhost",
          ATTR_HTTP_TARGET => "/test"
        }
      ) do |span|
        assert span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      assert_equal spans[0].attributes, {
        ATTR_HTTP_METHOD =>"GET",
        ATTR_HTTP_SCHEME =>"http",
        ATTR_NET_HOST_NAME =>"localhost",
        ATTR_HTTP_TARGET =>"/test",
        "SampleRate" => 1_000_000,
        "SampleSource" => 6,
        "BucketCapacity" => 10,
        "BucketRate" => 1
      }
    end

    it "picks up trigger-trace" do
      sampler = TestSampler.new(
      {
        local_settings: local_settings(trigger_trace: true),
        settings: settings(enabled: true)
      })

      replace_sampler(sampler)

      ctx = ::OpenTelemetry::Context.new({
        'sw_xtraceoptions' => 'trigger-trace'
      })

      ::OpenTelemetry::Context.with_current(ctx) do
        tracer.in_span("test") do |span|
          assert span.recording?
        end
      end

      spans = @memory_exporter.finished_spans
      assert_equal 1, spans.length
      _(spans[0].attributes['BucketCapacity']).must_equal 1
      _(spans[0].attributes['BucketRate']).must_equal 0.1
    end
  end
end
