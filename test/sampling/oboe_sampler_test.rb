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
require 'securerandom'
require 'openssl'

def make_span(options={})
  object = {
    name: options[:name] || 'span',
    trace_id: options[:trace_id] || SecureRandom.hex(16), # Random.bytes(16)
    id: options[:id] || SecureRandom.hex(8), # Random.bytes(8)
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
  trace_id = parent ? parent.context.trace_id : SecureRandom.hex(16)

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

  def local_settings
    # { tracing_mode: true, trigger_mode: false }
    @local_settings
  end
end

describe "OboeSampler" do
  TEST_OTEL_SAMPLING_DECISION = ::OpenTelemetry::SDK::Trace::Samplers::Decision

  before do
    OpenTelemetry::SDK.configure
    @metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    OpenTelemetry.meter_provider.add_metric_reader(@metric_exporter)
  end

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
        local_settings: { triggerMode: false },
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
        local_settings: { triggerMode: false },
        request_headers: {}
      )

      parent = make_span(remote: false, sampled: false)
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, [])
    end
  end
end

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
