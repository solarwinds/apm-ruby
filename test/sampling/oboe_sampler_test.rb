# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb

require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'
require './lib/solarwinds_apm/sampling/metrics'
require './lib/solarwinds_apm/sampling/trace_options'
require './lib/solarwinds_apm/sampling/oboe_sampler'
require './lib/solarwinds_apm/sampling/settings'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/sampling/dice'
require 'securerandom'
require 'openssl'

def make_span(options={})
  object = {
    name: options[:name] || 'span',
    trace_id: options[:trace_id] || Random.bytes(16),
    id: options[:id] || Random.bytes(8),
    remote: options[:remote],
    sampled: options[:sampled] || true
  }

  if options[:sw] == 'inverse'
    sw_flags = object[:sampled] ? '00' : '01'
  else
    sw_flags = object[:sampled] ? '01' : '00'
  end

  span_context = OpenTelemetry::Trace::SpanContext.new(span_id: object[:id],
                                                       trace_id: object[:trace_id],
                                                       remote: object[:remote],
                                                       trace_flags: object[:sampled] ? OpenTelemetry::Trace::TraceFlags::SAMPLED : OpenTelemetry::Trace::TraceFlags::DEFAULT,
                                                       tracestate: options[:sw].nil? ? OpenTelemetry::Trace::Tracestate::DEFAULT : OpenTelemetry::Trace::Tracestate::from_string("sw=#{object[:id]}-#{sw_flags}")
                                                       )
  OpenTelemetry::SDK::Trace::Span.new(span_context,
                                      OpenTelemetry::Context.empty,
                                      OpenTelemetry::Trace::Span::INVALID,
                                      'name',
                                      OpenTelemetry::Trace::SpanKind::INTERNAL,
                                      nil,
                                      OpenTelemetry::SDK::Trace::SpanLimits.new,
                                      [],
                                      { 'net.peer.name' => 'sample-rails', 'net.peer.port' => 8002 },
                                      nil,
                                      Time.now,
                                      nil,
                                      nil)
end


def make_request_headers(options = {})
  return {} unless options[:trigger_trace] || options[:kvs] || options[:signature]

  timestamp = Time.now.to_i
  timestamp -= 10 * 60 if options[:signature] == "bad-timestamp"
  ts = "ts=#{timestamp}"

  trigger_trace = options[:trigger_trace] ? "trigger-trace" : nil
  kvs = options[:kvs]&.map { |k, v| "#{k}=#{v}" } || []

  headers = {
    "X-Trace-Options" => [trigger_trace, *kvs, ts].compact.join(";")
  }

  if options[:signature]
    options[:signature_key] ||= SecureRandom.random_bytes(8)
    hmac = OpenSSL::HMAC.new(options[:signature_key], OpenSSL::Digest.new('sha1'))
    hmac.update(headers["X-Trace-Options"])
    headers["X-Trace-Options-Signature"] = hmac.digest.unpack1('H*')
  end

  headers
end

def make_sample_params(options = {})
  parent = options.fetch(:parent, make_span(name: "parent span"))
  name_ = options.fetch(:name, "child span")
  kind = options.fetch(:kind, OpenTelemetry::Trace::SpanKind::INTERNAL)

  tracer = OpenTelemetry.tracer_provider.tracer('')

  # function setSpan(context: Context, span: Span)
  # trace.setSpan(ROOT_CONTEXT, object.parent)

  # start_span(name, with_parent: nil, attributes: nil, links: nil, start_timestamp: nil, kind: nil)
  trace_context = parent ? OpenTelemetry::Trace.context_with_span(parent) : OpenTelemetry::Context::ROOT
  trace_id = parent ? parent.context.trace_id : Random.bytes(16)

  {
    trace_id: trace_id,
    trace_context: trace_context,
    links: nil,
    name: name_,
    kind: kind,
    attributes: {}
  }
end

# need to create a memory based metrics exporter and assert the value here
# check counters should check the counter number based on sampling decision
# counters name should have array of string
def check_counters(metric_exporter, counters=[])
  metric_exporter.pull
  last_snapshot = metric_exporter.metric_snapshots
  last_snapshot_hash = Hash[last_snapshot.map { |value| [value.name, value.data_points] }]
  counters.each do |counter_name|
    _(last_snapshot_hash[counter_name][0].value).must_equal 1
  end
end

class TestSampler < SolarWindsAPM::OboeSampler
  attr_accessor :response_headers, :local_settings, :request_headers

  def initialize(options)
    super(Logger.new($STDOUT))
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

describe "OboeSampler" do
  TEST_OTEL_SAMPLING_DECISION = ::OpenTelemetry::SDK::Trace::Samplers::Decision

  before do
    OpenTelemetry::SDK.configure
    @metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    OpenTelemetry.meter_provider.add_metric_reader(@metric_exporter)
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /LOCAL\ span/
  describe "LOCAL span" do
    it "respects parent sampled" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 10
        },
        local_settings: { tracing_mode: false },
        request_headers: {}
      )

      parent = make_span(remote: false, sampled: true)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, [])
    end

    it "respects parent not sampled" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 10
        },
        local_settings: { tracing_mode: false },
        request_headers: {}
      )

      parent = make_span(remote: false, sampled: false)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, [])
    end
  end

  describe "invalid X-Trace-Options-Signature" do
    it "rejects missing signature key" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SampleSource::REMOTE,
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10,
        },
        local_settings: { trigger_mode: true },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: true,
          kvs: { "custom-key" => "value" }
        )
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_nil sample.attributes
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "auth=no-signature-key"

      check_counters(@metric_exporter,["trace.service.request_count"])
    end

    it "rejects bad timestamp" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SampleSource::REMOTE,
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          signature_key: "key".b,
          timestamp: Time.now.to_i,
          ttl: 10,
        },
        local_settings: { trigger_mode: true },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: "bad-timestamp",
          signature_key: "key".b,
          kvs: { "custom-key" => "value" }
        )
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_nil sample.attributes
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "auth=bad-timestamp"

      check_counters(@metric_exporter,["trace.service.request_count"])
    end

    it "rejects bad signature" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SampleSource::REMOTE,
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          signature_key: "key1".b,
          timestamp: Time.now.to_i,
          ttl: 10,
        },
        local_settings: { trigger_mode: true },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: true,
          signature_key: "key2".b,
          kvs: { "custom-key" => "value" }
        )
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_nil sample.attributes
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "auth=bad-signature"

      check_counters(@metric_exporter,["trace.service.request_count"])
    end
  end

  describe "missing settings" do
    it "doesn't sample" do
      sampler = TestSampler.new(
        settings: false,
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter,["trace.service.request_count"])
    end

    it "expires after ttl" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i - 60,
          ttl: 10,
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      parent = make_span(remote: true, sw: true, sampled: true)
      params = make_sample_params(parent: parent)

      sleep(0.01) # Simulating setTimeout(10)
      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter,["trace.service.request_count"])
    end

    it "respects X-Trace-Options keys and values" do
      sampler = TestSampler.new(
        settings: false,
        local_settings: { trigger_mode: false },
        request_headers: make_request_headers(
          kvs: { "custom-key" => "value", "sw-keys" => "sw-values" }
        )
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_includes sample.attributes, { "custom-key" => "value", "SWKeys" => "sw-values" }
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=not-requested"
    end

    it "ignores trigger-trace" do
      sampler = TestSampler.new(
        settings: false,
        local_settings: { trigger_mode: true },
        request_headers: make_request_headers(
          trigger_trace: true,
          kvs: { "custom-key" => "value", "invalid-key" => "value" }
        )
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_includes sample.attributes, { "custom-key" => "value" }
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=settings-not-available"
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"
    end
  end

  describe "ENTRY span with valid sw context" do
    describe "X-Trace-Options" do
      it "respects keys and values" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: make_request_headers(
            kvs: { "custom-key" => "value", "sw-keys" => "sw-values" }
          )
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_includes sample.attributes, { "custom-key" => "value", "SWKeys" => "sw-values" }
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=not-requested"
      end

      it "ignores trigger-trace" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: true },
          request_headers: make_request_headers(
            trigger_trace: true,
            kvs: { "custom-key" => "value", "invalid-key" => "value" }
          )
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_includes sample.attributes, { "custom-key" => "value" }
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=ignored"
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"
      end
    end

    describe "SAMPLE_THROUGH_ALWAYS set" do
      before do
        @sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: {}
        )
      end

      it "respects parent sampled" do
        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
        assert_includes sample.attributes, { "sw.tracestate_parent_id" => parent.context.span_id }

        check_counters([
          "trace.service.request_count",
          "trace.service.tracecount",
          "trace.service.through_trace_count",
        ])
      end

      it "respects parent not sampled" do
        parent = make_span(remote: true, sw: true, sampled: false)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_includes sample.attributes, { "sw.tracestate_parent_id" => parent.context.span_id }

        check_counters(@metric_exporter,["trace.service.request_count"])
      end
    end

    describe "SAMPLE_THROUGH_ALWAYS unset" do
      it "records but does not sample when SAMPLE_START set" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_START,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: {}
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

        check_counters(@metric_exporter,["trace.service.request_count"])
      end

      it "does not record or sample when SAMPLE_START unset" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: 0x0,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: {}
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

        check_counters(@metric_exporter,["trace.service.request_count"])
      end
    end
  end

  describe "trigger-trace requested" do
    describe "TRIGGERED_TRACE set" do
      describe "unsigned" do
        it "records and samples when there is capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 10, rate: 5 },
                "TriggerRelaxed" => { capacity: 0, rate: 0 },
              },
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "sw-keys" => "sw-values" }
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "SWKeys" => "sw-values",
            "BucketCapacity" => 10,
            "BucketRate" => 5,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=ok"

          check_counters([
            "trace.service.request_count",
            "trace.service.tracecount",
            "trace.service.triggered_trace_count",
          ])
        end

        it "records but doesn't sample when there is no capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 0, rate: 0 },
                "TriggerRelaxed" => { capacity: 20, rate: 10 },
              },
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "invalid-key" => "value" }
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "BucketCapacity" => 0,
            "BucketRate" => 0,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=rate-exceeded"
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"

          check_counters(@metric_exporter,["trace.service.request_count"])
        end
      end

      describe "signed" do
        it "records and samples when there is capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 0, rate: 0 },
                "TriggerRelaxed" => { capacity: 20, rate: 10 },
              },
              signature_key: "key",
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "sw-keys" => "sw-values" },
              signature: true,
              signature_key: "key"
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "SWKeys" => "sw-values",
            "BucketCapacity" => 20,
            "BucketRate" => 10,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "auth=ok"
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=ok"

          check_counters([
            "trace.service.request_count",
            "trace.service.tracecount",
            "trace.service.triggered_trace_count",
          ])
        end
      end
    end

    describe "TRIGGERED_TRACE unset" do
      it "records but does not sample when TRIGGERED_TRACE is unset" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_START,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: make_request_headers(
            trigger_trace: true,
            kvs: { "custom-key" => "value", "invalid-key" => "value" }
          )
        )

        parent = make_span(remote: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_includes sample.attributes, { "custom-key" => "value" }
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=trigger-tracing-disabled"
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"

        check_counters(@metric_exporter,["trace.service.request_count"])
      end
    end
  end

  describe "trigger-trace requested" do
    describe "TRIGGERED_TRACE set" do
      describe "unsigned" do
        it "records and samples when there is capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 10, rate: 5 },
                "TriggerRelaxed" => { capacity: 0, rate: 0 },
              },
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "sw-keys" => "sw-values" }
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "SWKeys" => "sw-values",
            "BucketCapacity" => 10,
            "BucketRate" => 5,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=ok"

          check_counters([
            "trace.service.request_count",
            "trace.service.tracecount",
            "trace.service.triggered_trace_count",
          ])
        end

        it "records but doesn't sample when there is no capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 0, rate: 0 },
                "TriggerRelaxed" => { capacity: 20, rate: 10 },
              },
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "invalid-key" => "value" }
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "BucketCapacity" => 0,
            "BucketRate" => 0,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=rate-exceeded"
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"

          check_counters(@metric_exporter,["trace.service.request_count"])
        end
      end

      describe "signed" do
        it "records and samples when there is capacity" do
          sampler = TestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SampleSource::LOCAL_DEFAULT,
              flags: Flags::SAMPLE_START | Flags::TRIGGERED_TRACE,
              buckets: {
                "TriggerStrict" => { capacity: 0, rate: 0 },
                "TriggerRelaxed" => { capacity: 20, rate: 10 },
              },
              signature_key: "key",
              timestamp: Time.now.to_i,
              ttl: 10,
            },
            local_settings: { trigger_mode: true },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { "custom-key" => "value", "sw-keys" => "sw-values" },
              signature: true,
              signature_key: "key"
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
          assert_includes sample.attributes, {
            "custom-key" => "value",
            "SWKeys" => "sw-values",
            "BucketCapacity" => 20,
            "BucketRate" => 10,
          }
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "auth=ok"
          assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=ok"

          check_counters([
            "trace.service.request_count",
            "trace.service.tracecount",
            "trace.service.triggered_trace_count",
          ])
        end
      end
    end

    describe "TRIGGERED_TRACE unset" do
      it "records but does not sample when TRIGGERED_TRACE is unset" do
        sampler = TestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SampleSource::LOCAL_DEFAULT,
            flags: Flags::SAMPLE_START,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10,
          },
          local_settings: { trigger_mode: false },
          request_headers: make_request_headers(
            trigger_trace: true,
            kvs: { "custom-key" => "value", "invalid-key" => "value" }
          )
        )

        parent = make_span(remote: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_includes sample.attributes, { "custom-key" => "value" }
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=trigger-tracing-disabled"
        assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"

        check_counters(@metric_exporter,["trace.service.request_count"])
      end
    end
  end


  describe "dice roll" do
    it "respects X-Trace-Options keys and values" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_START,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: make_request_headers(kvs: { "custom-key" => "value", "sw-keys" => "sw-values" })
      )

      parent = make_span(remote: true, sampled: false)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_includes sample.attributes, { "custom-key" => "value", "SWKeys" => "sw-values" }
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=not-requested"
    end

    it "records and samples when dice success and sufficient capacity" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SampleSource::REMOTE,
          flags: Flags::SAMPLE_START,
          buckets: { BucketType::DEFAULT => { capacity: 10, rate: 5 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
      assert_includes sample.attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 10,
        BucketRate: 5
      }

      check_counters(@metric_exporter,["trace.service.request_count", "trace.service.samplecount", "trace.service.tracecount"])
    end

    it "records but doesn't sample when dice success but insufficient capacity" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SampleSource::REMOTE,
          flags: Flags::SAMPLE_START,
          buckets: { BucketType::DEFAULT => { capacity: 0, rate: 0 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
      assert_includes sample.attributes, {
        SampleRate: 1_000_000,
        SampleSource: 6,
        BucketCapacity: 0,
        BucketRate: 0
      }

      check_counters(@metric_exporter,["trace.service.request_count", "trace.service.samplecount", "trace.service.tokenbucket_exhaustion_count"])
    end

    it "records but doesn't sample when dice failure" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_START,
          buckets: { BucketType::DEFAULT => { capacity: 10, rate: 5 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
      assert_includes sample.attributes, { SampleRate: 0, SampleSource: 2 }
      refute sample.attributes.key?(:BucketCapacity)
      refute sample.attributes.key?(:BucketRate)

      check_counters(@metric_exporter,["trace.service.request_count", "trace.service.samplecount"])
    end
  end

  describe "SAMPLE_START unset" do
    it "ignores trigger-trace" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: true },
        request_headers: make_request_headers(
          trigger_trace: true,
          kvs: { "custom-key" => "value", "invalid-key" => "value" }
        )
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_includes sample.attributes, { "custom-key" => "value" }
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "trigger-trace=tracing-disabled"
      assert_includes sampler.response_headers["X-Trace-Options-Response"], "ignored=invalid-key"
    end

    it "records when SAMPLE_THROUGH_ALWAYS set" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
      check_counters(@metric_exporter,["trace.service.request_count"])
    end

    it "doesn't record when SAMPLE_THROUGH_ALWAYS unset" do
      sampler = TestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: false },
        request_headers: {}
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      check_counters(@metric_exporter,["trace.service.request_count"])
    end
  end

end

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /spanType/
describe 'SolarWindsAPM OboeSampler Test' do
  describe "spanType" do
    it "identifies no parent as ROOT" do
      type = SpanType.span_type(nil)
      assert_equal SpanType::ROOT, type
    end

    # isSpanContextValid may have more restrict then ruby valid?
    # js isSpanContextValid test if trace_id and span_id is valid format and not invalid like 00000...
    # need to have our own isSpanContextValid function
    it "identifies invalid parent as ROOT" do
      parent = make_span({id: "woops"})

      type = SpanType.span_type(parent)
      assert_equal SpanType::ROOT, type
    end

    it "identifies remote parent as ENTRY" do
      parent = make_span({remote: true})

      type = SpanType.span_type(parent)
      assert_equal SpanType::ENTRY, type
    end

    it "identifies local parent as LOCAL" do
      parent = make_span({remote: false})

      type = SpanType.span_type(parent)
      assert_equal SpanType::LOCAL, type
    end
  end
end
