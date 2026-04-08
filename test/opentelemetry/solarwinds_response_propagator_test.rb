# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/opentelemetry/solarwinds_response_propagator'

describe 'SolarWindsResponsePropagator extract passthrough and inject x-trace headers' do
  before do
    @propagator = SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
  end

  describe 'extract' do
    it 'returns context unchanged' do
      context = OpenTelemetry::Context.empty
      result = @propagator.extract({}, context: context)
      assert_equal context, result
    end
  end

  describe 'inject' do
    it 'injects x-trace header for valid span context' do
      raw_span_id  = Random.bytes(8)
      raw_trace_id = Random.bytes(16)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: raw_span_id,
        trace_id: raw_trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED,
        tracestate: OpenTelemetry::Trace::Tracestate.from_hash({})
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      expected_x_trace = "00-#{raw_trace_id.unpack1('H*')}-#{raw_span_id.unpack1('H*')}-01"
      assert carrier.key?('x-trace')
      assert_equal expected_x_trace, carrier['x-trace']
      assert carrier.key?('Access-Control-Expose-Headers')
      assert_equal 'x-trace', carrier['Access-Control-Expose-Headers']
    end

    it 'injects x-trace-options-response when xtrace_options_response in tracestate' do
      raw_span_id  = Random.bytes(8)
      raw_trace_id = Random.bytes(16)
      tracestate = OpenTelemetry::Trace::Tracestate.from_hash({
                                                                'xtrace_options_response' => 'auth:ok;trigger-trace:ok'
                                                              })
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: raw_span_id,
        trace_id: raw_trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED,
        tracestate: tracestate
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      assert carrier.key?('x-trace-options-response')
      assert_equal 'auth=ok;trigger-trace=ok', carrier['x-trace-options-response']
      assert_equal 'x-trace,x-trace-options-response', carrier['Access-Control-Expose-Headers']
    end

    it 'does not inject for invalid span context' do
      context = OpenTelemetry::Context.empty
      carrier = {}
      @propagator.inject(carrier, context: context)

      refute carrier.key?('x-trace')
    end

    it 'does not include x-trace-options-response when empty' do
      tracestate = OpenTelemetry::Trace::Tracestate.from_hash({})
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: Random.bytes(8),
        trace_id: Random.bytes(16),
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED,
        tracestate: tracestate
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      refute carrier.key?('x-trace-options-response')
    end
  end
end
