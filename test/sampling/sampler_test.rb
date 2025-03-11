# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/sampler_test.rb
require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require './lib/solarwinds_apm/sampling'

class TestSampler < SolarWindsAPM::Sampler
  attr_accessor :response_headers, :local_settings, :request_headers

  def initialize(options)
    super(options, Logger.new($STDOUT))
    @local_settings = options[:local_settings]
    @request_headers = options[:request_headers]
    @response_headers = nil

    update_settings(options[:settings]) if options[:settings]
  end

  # return { tracing_mode:, trigger_mode: }
  def local_settings(params)
    @local_settings
  end

  def request_headers(params)
    @request_headers
  end
end

module DisableCounter
  def initialize; end
end

SolarWindsAPM::Metrics::Counter.prepend(DisableCounter)

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
      @sampler = TestSampler.new({})
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
      @sampler = TestSampler.new({})
    end

    it "correctly parses JSON settings" do
      timestamp = (Time.now.to_f * 1000).round / 1000

      json = {
        flags: "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE",
        value: 500_000,
        arguments: {
          BucketCapacity: 0.2,
          BucketRate: 0.1,
          TriggerRelaxedBucketCapacity: 20,
          TriggerRelaxedBucketRate: 10,
          TriggerStrictBucketCapacity: 2,
          TriggerStrictBucketRate: 1,
          SignatureKey: "key"
        },
        timestamp: timestamp,
        ttl: 120,
        warning: "warning"
      }

      setting = @sampler.parse_settings(json)

      expected_output = {
        sampleRate: 500_000,
        sampleSource: SampleSource::REMOTE,
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
        signatureKey: "key",
        timestamp: timestamp,
        ttl: 120,
        warning: "warning"
      }

      assert_equal expected_output, setting
    end
  end

  def settings(enabled: nil, signature_key: nil)
    {
      value: 1_000_000,
      flags: enabled ? "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE" : "",
      arguments: {
        BucketCapacity: 10,
        BucketRate: 1,
        TriggerRelaxedBucketCapacity: 100,
        TriggerRelaxedBucketRate: 10,
        TriggerStrictBucketCapacity: 1,
        TriggerStrictBucketRate: 0.1,
        SignatureKey: signature_key&.force_encoding("UTF-8"),
      },
      timestamp: Time.now.to_i,
      ttl: 60,
    }
  end

  def options(trigger_trace: nil, tracing_mode: nil, tranasction_settings: nil, enabled: nil, signature_key: nil)
    {
      tracing_mode: tracing_mode,
      trigger_trace_enabled: trigger_trace,
      tranasction_settings: tranasction_settings,
      settings: settings(enabled: enabled, signature_key: signature_key)
    }
  end

  describe "Sampler.name" do
    let(:tracer) { ::OpenTelemetry.tracer_provider.tracer("test") }
    it "respects enabled settings when no config or transaction settings" do
      # sampler = TestSampler.new(
      #   options(trigger_trace: false),
      #   settings(enabled: true)
      # )

      # options: {tracing_mode, trigger_trace_enabled, transaction_setting}
      # settings: {BucketCapacity, etc.}
      sampler = TestSampler.new(options(trigger_trace: false, enabled: true))

      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "respects disabled settings when no config or transaction settings" do
      sampler = TestSampler.new(options(trigger_trace: true))
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      # spans = otel.spans
      # assert_empty spans
    end

    it "respects enabled config when no transaction settings" do
      sampler = TestSampler.new(
        options(tracing_mode: true, trigger_trace: true)
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "respects disabled config when no transaction settings" do
      sampler = TestSampler.new(
        options(tracing_mode: false, trigger_trace: false)
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      # spans = otel.spans
      # assert_empty spans
    end

    it "respects enabled matching transaction setting" do
      sampler = TestSampler.new(
        options(tracing_mode: false, trigger_trace: false, tranasction_settings: [{ tracing: true, matcher: -> { true } }])
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "respects disabled matching transaction setting" do
      sampler = TestSampler.new(
        options(tracing_mode: true, trigger_trace: true, tranasction_settings: [{ tracing: false, matcher: -> { true } }])
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      # spans = otel.spans
      # assert_empty spans
    end

    it "respects first matching transaction setting" do
      sampler = TestSampler.new(
        options(tracing_mode: false, trigger_trace: false, tranasction_settings: [
          { tracing: true, matcher: -> { true } },
          { tracing: false, matcher: -> { true } }
        ])
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "matches non-http spans properly" do
      sampler = TestSampler.new(
        options(
          tracing_mode: false,
          trigger_trace: false,
          tranasction_settings: [
            { tracing: true, matcher: ->(name) { name == "CLIENT:test" } }
          ]
        )
      )
      # otel.reset(trace: { sampler: sampler })

      tracer.in_span("test", kind: ::OpenTelemetry::Trace::SpanKind::CLIENT) do |span|
        assert span.recording?
        span.finish
      end

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "matches http spans properly" do
      sampler = TestSampler.new(
        options(
          tracing_mode: false,
          trigger_trace: false,
          tranasction_settings: [
            { tracing: true, matcher: ->(name) { name == "http://localhost/test" } }
          ]
        )
      )
      # otel.reset(trace: { sampler: sampler })

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

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    it "matches deprecated http spans properly" do
      sampler = TestSampler.new(
        options(
          tracing_mode: false,
          trigger_trace: false,
          tranasction_settings: [
            { tracing: true, matcher: ->(name) { name == "http://localhost/test" } }
          ]
        )
      )
      # otel.reset(trace: { sampler: sampler })

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

      # spans = otel.spans
      assert_equal 1, spans.length
      assert_includes spans[0].attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 1
      }
    end

    # it "picks up trigger-trace" do
    #   sampler = TestSampler.new(
    #     options(trigger_trace: true)
    #   )
    #   # otel.reset(trace: { sampler: sampler })

    #   # current_context = ::OpenTelemetry::Context.current
    #   # ctx = ::OpenTelemetry::Context.new(current_context, {
    #   #   request: { "X-Trace-Options" => "trigger-trace" },
    #   #   response: {}
    #   # })

    #   # const ctx = HEADERS_STORAGE.set(context.active(), {
    #   #   request: { "X-Trace-Options": "trigger-trace" },
    #   #   response: {},
    #   # })

    #   # context.with(ctx, () => {
    #   #   trace.getTracer("test").startActiveSpan("test", (span) => {
    #   #     expect(span.isRecording()).to.be.true
    #   #     span.end()
    #   #   })
    #   # })

    #   context.with(ctx) do
    #     tracer.in_span("test") do |span|
    #       assert span.recording?
    #       span.finish
    #     end
    #   end

    #   # spans = otel.spans
    #   assert_equal 1, spans.length
    #   assert_includes spans[0].attributes, {
    #     BucketCapacity: 1,
    #     BucketRate: 0.1
    #   }

    #   assert_includes HEADERS_STORAGE.get(ctx)&.response, "X-Trace-Options-Response"
    # end
  end
end
