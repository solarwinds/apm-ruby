# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/support/transaction_settings'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/opentelemetry/solarwinds_propagator'

describe 'SolarWindsPropagatorTest' do
  before do
    @text_map_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    @propagator = @text_map_propagator
    @mock = Minitest::Mock.new
  end

  it 'returns a valid context when carrier is empty' do
    carrier = {}
    result = @text_map_propagator.extract(carrier)
    _(result.class.to_s).must_equal 'OpenTelemetry::Context'
  end

  it 'extracts x-trace-options and signature from carrier into context' do
    carrier = {}
    carrier['x-trace-options'] = 'foo'
    carrier['x-trace-options-signature'] = 'bar'
    result = @text_map_propagator.extract(carrier)

    _(result.value('sw_xtraceoptions')).must_equal 'foo'
    _(result.value('sw_signature')).must_equal 'bar'
  end

  it 'overwrites existing context values with new carrier headers' do
    carrier = {}
    carrier['x-trace-options'] = 'foo'
    carrier['x-trace-options-signature'] = 'bar'

    context_value = {}
    context_value['sw_xtraceoptions'] = 'sample_signature'
    context_value['sw_signature']     = 'sample_xtraceoptions'
    otel_context = OpenTelemetry::Context.new(context_value)

    result = @text_map_propagator.extract(carrier, context: otel_context)

    _(result.value('sw_xtraceoptions')).must_equal 'foo'
    _(result.value('sw_signature')).must_equal 'bar'
  end

  it 'calls current_span with context when injecting into empty carrier' do
    @mock.expect(:call, nil, [OpenTelemetry::Context])

    OpenTelemetry::Trace.stub(:current_span, @mock) do
      context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )

      carrier = {}
      @text_map_propagator.inject(carrier, context: context)
    end

    _(@mock.verify).must_equal true
  end

  it 'creates new tracestate when no tracestate header exists' do
    @mock.expect(:call, OpenTelemetry::Trace::Tracestate.create({}), [Hash])

    OpenTelemetry::Trace::Tracestate.stub(:create, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )

      carrier = {}
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

  it 'parses existing tracestate header and updates sw value' do
    @mock.expect(:call, OpenTelemetry::Trace::Tracestate.create({}), [String])

    OpenTelemetry::Trace::Tracestate.stub(:from_string, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )

      carrier = {}
      carrier['tracestate'] = 'abcd'
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

  it 'uses text_map_setter to set tracestate on carrier' do
    @mock.expect(:call, nil, [Hash, String, String])

    OpenTelemetry::Context::Propagation.text_map_setter.stub(:set, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )

      carrier = {}
      carrier['tracestate'] = 'abcd'
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

  describe 'extract' do
    it 'extracts x-trace-options header into context' do
      carrier = { 'x-trace-options' => 'trigger-trace;ts=12345' }
      context = @propagator.extract(carrier, context: OpenTelemetry::Context.empty)

      assert_equal 'trigger-trace;ts=12345', context.value('sw_xtraceoptions')
    end

    it 'returns context unchanged when no headers present' do
      carrier = {}
      original_context = OpenTelemetry::Context.empty
      context = @propagator.extract(carrier, context: original_context)

      assert_nil context.value('sw_xtraceoptions')
      assert_nil context.value('sw_signature')
    end

    it 'handles nil context gracefully' do
      carrier = { 'x-trace-options' => 'trigger-trace' }
      context = @propagator.extract(carrier, context: nil)
      assert_instance_of OpenTelemetry::Context, context
    end

    it 'handles exceptions gracefully' do
      carrier = nil
      context = @propagator.extract(carrier, context: OpenTelemetry::Context.empty)
      assert_instance_of OpenTelemetry::Context, context
    end
  end

  describe 'inject' do
    it 'injects sw tracestate when no existing tracestate' do
      span_id = Random.bytes(8)
      trace_id = Random.bytes(16)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: span_id,
        trace_id: trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      expected_sw = "#{span_id.unpack1('H*')}-01"
      assert_equal "sw=#{expected_sw}", carrier['tracestate']
    end

    it 'updates existing tracestate with sw value' do
      span_id = Random.bytes(8)
      trace_id = Random.bytes(16)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: span_id,
        trace_id: trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = { 'tracestate' => 'other=value' }
      @propagator.inject(carrier, context: context)

      expected_sw = "#{span_id.unpack1('H*')}-01"
      assert_equal "other=value,sw=#{expected_sw}", carrier['tracestate']
    end

    it 'does not inject when span context is invalid' do
      context = OpenTelemetry::Context.empty
      carrier = {}
      @propagator.inject(carrier, context: context)

      assert_nil carrier['tracestate']
    end

    it 'sets trace flag 01 for sampled spans' do
      span_id = Random.bytes(8)
      trace_id = Random.bytes(16)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: span_id,
        trace_id: trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      expected_sw = "#{span_id.unpack1('H*')}-01"
      assert_equal "sw=#{expected_sw}", carrier['tracestate']
    end

    it 'sets trace flag 00 for non-sampled spans' do
      span_id = Random.bytes(8)
      trace_id = Random.bytes(16)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: span_id,
        trace_id: trace_id,
        trace_flags: OpenTelemetry::Trace::TraceFlags::DEFAULT
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      context = OpenTelemetry::Trace.context_with_span(span)

      carrier = {}
      @propagator.inject(carrier, context: context)

      expected_sw = "#{span_id.unpack1('H*')}-00"
      assert_equal "sw=#{expected_sw}", carrier['tracestate']
    end
  end

  describe 'fields' do
    it 'returns tracestate' do
      assert_equal 'tracestate', @propagator.fields
    end
  end
end
