# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/sampling/sampling_patch'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'
require './lib/solarwinds_apm/sampling/metrics'
require './lib/solarwinds_apm/sampling/trace_options'
require './lib/solarwinds_apm/sampling/oboe_sampler'
require './lib/solarwinds_apm/sampling/settings'
require './lib/solarwinds_apm/sampling/dice'
require 'sampling_test_helper'
require 'opentelemetry-metrics-sdk'

# Integration test: replicates every step performed by SolarWindsAPM::OTelConfig.initialize
# in a self-contained test environment (no real service key or external APM backend required).
#
# Steps mirrored from OTelConfig.initialize (lib/solarwinds_apm/otel_config.rb):
#
#   Step 1 — OpenTelemetry::SDK.configure with SolarWinds resource attributes
#             (sw.apm.version, sw.data.module, service.name).
#   Step 2 — SolarWindsPropagator appended to the global propagation chain so
#             incoming x-trace-options / x-trace-options-signature headers are
#             extracted into the context.
#   Step 3 — TxnNameManager + OTLPProcessor created and added to the tracer
#             provider.  The processor detects entry spans, computes transaction
#             names, and records the trace.service.response_time histogram.
#   Step 4 — Parent-based sampler (OboeSampler) set on the tracer provider so
#             sampling decisions carry SampleRate / SampleSource / BucketCapacity
#             attributes onto spans.
#   Step 5 — SolarWindsResponsePropagator registered so the x-trace header is
#             injected into outbound response headers.
#
# The single test then exercises the assembled pipeline end-to-end:
#   • Incoming request with x-trace-options extracted by SolarWindsPropagator
#   • Root span sampled at 100 % via OboeSampler
#   • OTLPProcessor enriches the span (sw.is_entry_span, sw.transaction)
#   • Nested child spans are excluded from entry-span logic
#   • Response headers injected by SolarWindsResponsePropagator
#   • trace.service.response_time metric recorded with correct attributes
#   • Exported span carries the SolarWinds resource attributes
describe 'FullInitializationWorkflowIntegration' do
  it 'replicates all OTelConfig.initialize steps and exercises the complete SolarWinds pipeline' do
    # ── Step 1: Configure OTel SDK with SolarWinds resource attributes ───────────
    # Mirrors the OpenTelemetry::SDK.configure block in OTelConfig.initialize which
    # stamps every span with sw.apm.version, sw.data.module, and service.name.
    sw_version   = SolarWindsAPM::Version::STRING
    service_name = 'test-full-init-service'

    SolarWindsAPM::OpenTelemetry::OTLPProcessor.prepend(DisableAddView)

    resource = OpenTelemetry::SDK::Resources::Resource.create(
      'sw.apm.version' => sw_version,
      'sw.data.module' => 'apm',
      'service.name' => service_name
    )

    OpenTelemetry::SDK.configure do |c|
      c.resource = resource
    end

    # ── Step 2: Append SolarWindsPropagator to the global propagation chain ──────
    # Mirrors: OpenTelemetry.propagation.instance_variable_get(:@propagators).append(...)
    sw_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    OpenTelemetry.propagation.instance_variable_get(:@propagators)&.append(sw_propagator)

    # ── Step 3: Create TxnNameManager + OTLPProcessor ───────────────────────────
    # Mirrors: txn_manager = TxnNameManager.new
    #          otlp_processor = OTLPProcessor.new(txn_manager)
    #          OpenTelemetry.tracer_provider.add_span_processor(otlp_processor)
    txn_manager     = SolarWindsAPM::TxnNameManager.new
    otlp_processor  = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(txn_manager)

    metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    trace_exporter  = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    span_processor  = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(trace_exporter)

    OpenTelemetry.meter_provider.add_metric_reader(metric_exporter)

    # ── Step 4: Build parent-based OboeSampler ───────────────────────────────────
    # Mirrors: sampler = HttpSampler.new(sampler_config)
    #          OpenTelemetry.tracer_provider.sampler = parent_based(root: sampler, ...)
    # OboeTestSampler (from sampling_test_helper) extends OboeSampler and accepts
    # pre-loaded settings, removing the need for an active APM backend connection.
    oboe_sampler = OboeTestSampler.new(
      settings: {
        sample_rate: 1_000_000,
        sample_source: SolarWindsAPM::SampleSource::REMOTE,
        flags: SolarWindsAPM::Flags::SAMPLE_START,
        buckets: { SolarWindsAPM::BucketType::DEFAULT => { capacity: 10.0, rate: 1.0 } },
        timestamp: Time.now.to_i,
        ttl: 120
      },
      local_settings: { tracing_mode: nil },
      request_headers: {}
    )

    parent_based_sampler = OpenTelemetry::SDK::Trace::Samplers.parent_based(
      root: oboe_sampler,
      remote_parent_sampled: oboe_sampler,
      remote_parent_not_sampled: oboe_sampler
    )

    provider = OpenTelemetry.tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new(
      sampler: parent_based_sampler,
      resource: resource
    ).tap do |p|
      p.add_span_processor(span_processor)
      p.add_span_processor(otlp_processor)
    end

    # ── Step 5: Set up SolarWindsResponsePropagator ──────────────────────────────
    # Mirrors: resolve_response_propagator which registers the response propagator
    # in Rack instrumentation config.  In tests, we hold a direct reference.
    response_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new

    # ── Verify Step 2: propagator is registered in the global chain ──────────────
    registered_propagators = OpenTelemetry.propagation.instance_variable_get(:@propagators)
    assert registered_propagators.any?(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator),
           'SolarWindsPropagator should be registered in the global propagation chain'

    # ── Full pipeline: incoming request with x-trace-options headers ─────────────
    # Simulate a browser / upstream service sending SolarWinds-specific headers.
    incoming_carrier = {
      'x-trace-options' => 'custom-app=checkout-service;sw-keys=reporting-host:web01',
      'x-trace-options-signature' => 'test-sig'
    }

    # Step 2 in action: extract sw context from incoming headers
    extracted_context = sw_propagator.extract(incoming_carrier)

    _(extracted_context.value('sw_xtraceoptions')).must_equal 'custom-app=checkout-service;sw-keys=reporting-host:web01',
                                                              'SolarWindsPropagator should extract x-trace-options into context'
    _(extracted_context.value('sw_signature')).must_equal 'test-sig',
                                                          'SolarWindsPropagator should extract x-trace-options-signature into context'

    tracer = provider.tracer(service_name, '1.0.0')

    OpenTelemetry::Context.with_current(OpenTelemetry::Context.empty) do
      tracer.in_span('GET /api/checkout', kind: :server, attributes: {
                       'http.method' => 'GET',
                       'http.route' => '/api/checkout',
                       'http.status_code' => 200
                     }) do |entry_span|
        # ── Verify Step 3 (on_start): OTLPProcessor marks entry span ─────────────
        _(entry_span.attributes['sw.is_entry_span']).must_equal true,
                                                                'OTLPProcessor.on_start should set sw.is_entry_span=true on the root server span'

        # ── Verify Step 3: TxnNameManager is tracking this trace ─────────────────
        trace_id  = entry_span.context.hex_trace_id
        root_ctx  = txn_manager.get_root_context_h(trace_id)
        refute_nil root_ctx, 'TxnNameManager should record the root context for the active trace'
        assert_match(/^[0-9a-f]{16}-0[01]$/, root_ctx, 'Root context should be span_id-trace_flags format')

        # ── Verify Step 4: OboeSampler placed sampling attributes on the span ─────
        _(entry_span.attributes['SampleRate']).must_equal 1_000_000,
                                                          'OboeSampler should attach SampleRate to the root span'
        _(entry_span.attributes['SampleSource']).must_equal SolarWindsAPM::SampleSource::REMOTE,
                                                            'OboeSampler should attach SampleSource to the root span'
        refute_nil entry_span.attributes['BucketCapacity'], 'OboeSampler should attach BucketCapacity'
        refute_nil entry_span.attributes['BucketRate'],     'OboeSampler should attach BucketRate'

        # ── Nested child span: should NOT be treated as an entry span ────────────
        tracer.in_span('SELECT * FROM carts', kind: :client) do |db_span|
          assert_nil db_span.attributes['sw.is_entry_span'],
                     'Child (client) span should not receive sw.is_entry_span'
          assert_nil db_span.attributes['SampleRate'],
                     'Sampler attributes should only appear on the root entry span'
        end

        # ── Verify Step 5: SolarWindsResponsePropagator injects response headers ─
        response_carrier = {}
        response_propagator.inject(response_carrier, context: OpenTelemetry::Trace.context_with_span(entry_span))

        x_trace = response_carrier['x-trace']
        refute_nil x_trace, 'SolarWindsResponsePropagator should inject the x-trace header'
        assert_match(/^00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]$/, x_trace,
                     'x-trace should be a valid W3C traceparent')
        assert x_trace.end_with?('-01'),
               'Sampled span (trace_flags=01) should produce x-trace ending in -01'

        exposed_headers = response_carrier['Access-Control-Expose-Headers']
        assert_includes exposed_headers, 'x-trace',
                        'SolarWindsResponsePropagator should expose x-trace in CORS headers'
      end
    end

    # ── Verify Step 3 (on_finishing): sw.transaction set on exported span ────────
    finished = trace_exporter.finished_spans
    _(finished.size).must_equal 2, 'Both the entry span and the child DB span should be exported'

    entry_span_data = finished.find { |s| s.attributes['sw.is_entry_span'] == true }
    refute_nil entry_span_data, 'Exported span should carry sw.is_entry_span=true'

    _(entry_span_data.attributes['sw.transaction']).must_equal '/api/checkout',
                                                               'OTLPProcessor.on_finishing should set sw.transaction to http.route'

    # ── Verify Step 1: resource attributes are stamped on the exported span ──────
    resource_attrs = entry_span_data.resource.attribute_enumerator.to_h
    _(resource_attrs['sw.apm.version']).must_equal sw_version,
                                                   'Span resource should carry sw.apm.version from SDK configure'
    _(resource_attrs['sw.data.module']).must_equal 'apm',
                                                   'Span resource should carry sw.data.module=apm'
    _(resource_attrs['service.name']).must_equal service_name,
                                                 'Span resource should carry the configured service.name'

    # ── Verify Step 3 (on_finish): trace.service.response_time metric recorded ───
    metric_exporter.pull
    metrics       = metric_exporter.metric_snapshots
    response_time = metrics.find { |m| m.name == 'trace.service.response_time' }
    refute_nil response_time, 'OTLPProcessor should record trace.service.response_time for the entry span'

    _(response_time.data_points.size).must_equal 1, 'Only the entry span should produce a metric data point'

    dp = response_time.data_points.first
    _(dp.attributes['sw.transaction']).must_equal '/api/checkout'
    _(dp.attributes['sw.is_error']).must_equal false
    _(dp.attributes['http.method']).must_equal 'GET'
    _(dp.attributes['http.status_code']).must_equal 200
  ensure
    # Remove the test-registered propagator so it does not leak into other tests
    propagators = OpenTelemetry.propagation.instance_variable_get(:@propagators)
    propagators&.delete_if { |p| p.is_a?(SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator) }
  end
end
