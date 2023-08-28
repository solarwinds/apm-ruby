# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/x_trace_options'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/transformer'
require './lib/solarwinds_apm/support/transaction_cache'
require './lib/solarwinds_apm/support/transaction_settings'
require './lib/solarwinds_apm/support/oboe_tracing_mode'
require './lib/solarwinds_apm/config'

describe 'SolarWindsPropagatorTest' do
  
  before do
    @text_map_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    @mock = Minitest::Mock.new
  end

  it 'test extract for empty carrier' do
    carrier = {}
    result = @text_map_propagator.extract(carrier)
    _(result.class.to_s).must_equal "OpenTelemetry::Context"
  end

  it 'test extract for non-empty carrier' do
    carrier = {} 
    carrier["x-trace-options"] = "foo"
    carrier["x-trace-options-signature"] = "bar"
    result = @text_map_propagator.extract(carrier)

    _(result.value("sw_xtraceoptions")).must_equal "foo"
    _(result.value("sw_signature")).must_equal "bar"
  end

  it 'test extract for non-empty carrier and context' do
    carrier = {} 
    carrier["x-trace-options"] = "foo"
    carrier["x-trace-options-signature"] = "bar"

    context_value = {}
    context_value["sw_xtraceoptions"] = "sample_signature"
    context_value["sw_signature"]     = "sample_xtraceoptions"
    otel_context = ::OpenTelemetry::Context.new(context_value)

    result = @text_map_propagator.extract(carrier, context: otel_context)

    _(result.value("sw_xtraceoptions")).must_equal "foo"
    _(result.value("sw_signature")).must_equal "bar"

  end

  it 'test inject for empty carrier and valid context' do

    @mock.expect(:call, nil, [OpenTelemetry::Context])

    ::OpenTelemetry::Trace.stub(:current_span, @mock) do
      context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED)

      carrier = {}
      @text_map_propagator.inject(carrier, context: context)
    end

    _(@mock.verify).must_equal true
  end

  it 'test inject for trace_state_header is nil (create new trace state)' do

    @mock.expect(:call, ::OpenTelemetry::Trace::Tracestate.create({}), [Hash])

    ::OpenTelemetry::Trace::Tracestate.stub(:create, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED)

      carrier = {}
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

  it 'test inject for trace_state_header is not nil trace state set_values' do

    @mock.expect(:call, ::OpenTelemetry::Trace::Tracestate.create({}), [String])

    ::OpenTelemetry::Trace::Tracestate.stub(:from_string, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED)

      carrier = {}
      carrier["tracestate"] = "abcd"
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

  it 'test inject for check setter' do

    @mock.expect(:call, nil, [Hash, String, String])

    ::OpenTelemetry::Context::Propagation.text_map_setter.stub(:set, @mock) do
      otel_context = create_context(
        trace_id: '80f198ee56343ba864fe8b2a57d3eff7',
        span_id: 'e457b5a2e4d86bd1',
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED)

      carrier = {}
      carrier["tracestate"] = "abcd"
      @text_map_propagator.inject(carrier, context: otel_context)
    end

    _(@mock.verify).must_equal true
  end

end
