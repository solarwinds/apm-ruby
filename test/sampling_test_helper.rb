# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require 'opentelemetry-test-helpers'
require './lib/solarwinds_apm/sampling'
require 'simplecov'
SimpleCov.start

ENV['OTEL_METRICS_EXPORTER'] = 'none'

ATTR_HTTP_REQUEST_METHOD = 'http.request.method'
ATTR_HTTP_RESPONSE_STATUS_CODE = 'http.response.status_code'
ATTR_SERVER_ADDRESS = 'server.address'
ATTR_URL_SCHEME = 'url.scheme'
ATTR_URL_PATH = 'url.path'
ATTR_NETWORK_TRANSPORT = 'network.transport'
ATTR_HTTP_STATUS_CODE = OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE
ATTR_HTTP_METHOD = OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD
ATTR_HTTP_SCHEME = OpenTelemetry::SemanticConventions::Trace::HTTP_SCHEME
ATTR_NET_HOST_NAME = OpenTelemetry::SemanticConventions::Trace::NET_HOST_NAME
ATTR_HTTP_TARGET = OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET
TEST_OTEL_SAMPLING_DECISION = OpenTelemetry::SDK::Trace::Samplers::Decision

class TestSampler < SolarWindsAPM::Sampler
  def initialize(options)
    logger = Logger.new($stdout)
    logger.level = ENV['TEST_LOGGER_DEBUG_LEVEL'].nil? ? 6 : ENV['TEST_LOGGER_DEBUG_LEVEL'].to_i
    super(options[:local_settings], logger)
    update_settings(options[:settings]) if options[:settings]
  end
end

def make_span(options = {})
  object = {
    name: options[:name] || 'span',
    trace_id: options[:trace_id] || Random.bytes(16),
    id: options[:id] || Random.bytes(8),
    remote: options[:remote],
    sampled: options[:sampled] == true
  }

  object[:trace_id].unpack1('H*')
  hex_span_id = object[:id].unpack1('H*')

  sw_flags = if options[:sw] == 'inverse'
               object[:sampled] ? '00' : '01'
             else
               object[:sampled] ? '01' : '00'
             end

  span_context = OpenTelemetry::Trace::SpanContext.new(span_id: object[:id],
                                                       trace_id: object[:trace_id],
                                                       remote: object[:remote],
                                                       trace_flags: object[:sampled] ? OpenTelemetry::Trace::TraceFlags::SAMPLED : OpenTelemetry::Trace::TraceFlags::DEFAULT,
                                                       tracestate: options[:sw] ? OpenTelemetry::Trace::Tracestate.from_string("sw=#{hex_span_id}-#{sw_flags}") : OpenTelemetry::Trace::Tracestate::DEFAULT)
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
  timestamp -= 10 * 60 if options[:signature] == 'bad-timestamp'
  ts = "ts=#{timestamp}"

  trigger_trace = options[:trigger_trace] ? 'trigger-trace' : nil
  kvs = options[:kvs]&.map { |k, v| "#{k}=#{v}" } || []

  headers = {
    'X-Trace-Options' => [trigger_trace, *kvs, ts].compact.join(';')
  }

  if options[:signature]
    options[:signature_key] ||= SecureRandom.random_bytes(8)
    hmac = OpenSSL::HMAC.new(options[:signature_key], OpenSSL::Digest.new('sha1'))
    hmac.update(headers['X-Trace-Options'])
    headers['X-Trace-Options-Signature'] = hmac.digest.unpack1('H*')
  end

  headers
end

def make_sample_params(options = {})
  parent = options.fetch(:parent, make_span(name: 'parent span'))
  name_ = options.fetch(:name, 'child span')
  kind = options.fetch(:kind, OpenTelemetry::Trace::SpanKind::INTERNAL)

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
def check_counters(metric_exporter, counters = [])
  metric_exporter.pull
  last_snapshot = metric_exporter.metric_snapshots
  last_snapshot_hash = last_snapshot.to_h { |value| [value.name, value.data_points] }
  counters.each do |counter_name|
    _(last_snapshot_hash[counter_name][0].value).must_equal 1
  end
end

# rubocop:disable Lint/DuplicateMethods
class OboeTestSampler < SolarWindsAPM::OboeSampler
  attr_accessor :response_headers, :local_settings, :request_headers

  def initialize(options)
    super(Logger.new($STDOUT))
    @local_settings = options[:local_settings]
    @request_headers = options[:request_headers]
    @response_headers = nil

    update_settings(options[:settings]) if options[:settings]
  end

  # return { tracing_mode:, trigger_mode: }
  def local_settings(_params)
    @local_settings
  end

  def request_headers(_params)
    @request_headers
  end
end
# rubocop:enable Lint/DuplicateMethods

def replace_sampler(sampler)
  OpenTelemetry.tracer_provider.sampler = OpenTelemetry::SDK::Trace::Samplers.parent_based(
    root: sampler,
    remote_parent_sampled: sampler,
    remote_parent_not_sampled: sampler
  )
end

module HttpSamplerTestPatch
  def retry_request; end

  def settings_request
    if @setting_url.hostname == 'collector.invalid'
      response = fetch_with_timeout(@setting_url)
      parsed = response.nil? ? { 'value' => 0, 'flags' => 'OVERRIDE', 'timestamp' => 1_741_963_365, 'ttl' => 120, 'arguments' => { 'BucketCapacity' => 0, 'BucketRate' => 0, 'TriggerRelaxedBucketCapacity' => 0, 'TriggerRelaxedBucketRate' => 0, 'TriggerStrictBucketCapacity' => 0, 'TriggerStrictBucketRate' => 0 }, 'warning' => 'Test Warning' } : JSON.parse(response.body)

      unless update_settings(parsed)
        @logger.warn { 'Retrieved sampling settings are invalid. Ensure proper configuration.' }
        retry_request
      end
    else
      super
    end
  end
end
SolarWindsAPM::HttpSampler.prepend(HttpSamplerTestPatch)
