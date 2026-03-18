# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support'
require './lib/solarwinds_apm/patch/tag_sql/sw_dbo_utils'

describe 'SWODboUtils#annotate_span_and_sql traceparent injection based on sampling state' do
  it 'returns sql unchanged for empty sql' do
    result = SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql('')
    assert_equal '', result
  end

  it 'returns sql unchanged for nil sql' do
    result = SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql(nil)
    assert_equal nil, result
  end

  it 'annotates sql with traceparent when span is sampled' do
    OpenTelemetry::SDK.configure
    tracer = OpenTelemetry.tracer_provider.tracer('test')

    result = nil
    tracer.in_span('test_span') do
      result = SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql('SELECT 1')
    end

    assert_includes result, 'SELECT 1'
    assert_includes result, "/*traceparent='"
  end

  it 'returns sql unchanged when span is not sampled' do
    OpenTelemetry::SDK.configure

    # Create unsampled span context
    trace_flags = OpenTelemetry::Trace::TraceFlags.from_byte(0x00)
    span_context = OpenTelemetry::Trace::SpanContext.new(trace_flags: trace_flags)
    span = OpenTelemetry::Trace::Span.new(span_context: span_context)

    OpenTelemetry::Context.with_value(OpenTelemetry::Trace.const_get(:CURRENT_SPAN_KEY), span) do
      result = SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql('SELECT 1')
      assert_equal 'SELECT 1', result
    end
  end
end
