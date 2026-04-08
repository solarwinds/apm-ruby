# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/utils'

describe 'Utils tracestate formatting, traceparent construction, and Lambda detection' do
  it 'builds W3C traceparent string from span context' do
    span_context = OpenTelemetry::Trace::SpanContext.new(trace_id: "\xDD\x95\xC5l\xE3\x83\xCA\xF0\x95;S\x98i\xF9:{",
                                                         span_id: "\x8D\xB5\xDC?$l\x84W")
    result = SolarWindsAPM::Utils.traceparent_from_context(span_context)
    assert_equal '00-dd95c56ce383caf0953b539869f93a7b-8db5dc3f246c8457-00', result
  end

  it 'formats tracestate hash into key=value header string' do
    tracestate = OpenTelemetry::Trace::Tracestate.from_hash({ 'sw' => '0000000000000000-01' })
    result = SolarWindsAPM::Utils.trace_state_header(tracestate)
    assert_equal 'sw=0000000000000000-01', result
  end

  describe 'trace_state_header' do
    it 'returns nil for nil tracestate' do
      assert_nil SolarWindsAPM::Utils.trace_state_header(nil)
    end

    it 'returns nil for empty tracestate' do
      tracestate = OpenTelemetry::Trace::Tracestate::DEFAULT
      assert_nil SolarWindsAPM::Utils.trace_state_header(tracestate)
    end

    it 'formats multiple tracestate entries' do
      tracestate = OpenTelemetry::Trace::Tracestate.from_hash({ 'sw' => '1234-01', 'other' => 'value' })
      result = SolarWindsAPM::Utils.trace_state_header(tracestate)
      assert_equal 'sw=1234-01,other=value', result
    end
  end

  describe 'traceparent_from_context' do
    it 'formats sampled span context' do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "\x8D\xB5\xDC?$l\x84W",
        trace_id: "\xDD\x95\xC5l\xE3\x83\xCA\xF0\x95;S\x98i\xF9:{",
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      result = SolarWindsAPM::Utils.traceparent_from_context(span_context)
      assert_equal '00-dd95c56ce383caf0953b539869f93a7b-8db5dc3f246c8457-01', result
    end

    it 'formats non-sampled span context' do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "\x8D\xB5\xDC?$l\x84W",
        trace_id: "\xDD\x95\xC5l\xE3\x83\xCA\xF0\x95;S\x98i\xF9:{",
        trace_flags: OpenTelemetry::Trace::TraceFlags::DEFAULT
      )
      result = SolarWindsAPM::Utils.traceparent_from_context(span_context)
      assert_equal '00-dd95c56ce383caf0953b539869f93a7b-8db5dc3f246c8457-00', result
    end
  end

  describe 'determine_lambda' do
    it 'returns false when not in lambda' do
      original_task_root = ENV.fetch('LAMBDA_TASK_ROOT', nil)
      original_func_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
      ENV.delete('LAMBDA_TASK_ROOT')
      ENV.delete('AWS_LAMBDA_FUNCTION_NAME')

      refute SolarWindsAPM::Utils.determine_lambda
    ensure
      original_task_root ? ENV['LAMBDA_TASK_ROOT'] = original_task_root : ENV.delete('LAMBDA_TASK_ROOT')
      original_func_name ? ENV['AWS_LAMBDA_FUNCTION_NAME'] = original_func_name : ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    end

    it 'returns true when LAMBDA_TASK_ROOT is set' do
      original = ENV.fetch('LAMBDA_TASK_ROOT', nil)
      ENV['LAMBDA_TASK_ROOT'] = '/var/task'

      assert SolarWindsAPM::Utils.determine_lambda
    ensure
      original ? ENV['LAMBDA_TASK_ROOT'] = original : ENV.delete('LAMBDA_TASK_ROOT')
    end

    it 'returns true when AWS_LAMBDA_FUNCTION_NAME is set' do
      original_task_root = ENV.fetch('LAMBDA_TASK_ROOT', nil)
      original_func_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
      ENV.delete('LAMBDA_TASK_ROOT')
      ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-function'

      assert SolarWindsAPM::Utils.determine_lambda
    ensure
      original_task_root ? ENV['LAMBDA_TASK_ROOT'] = original_task_root : ENV.delete('LAMBDA_TASK_ROOT')
      original_func_name ? ENV['AWS_LAMBDA_FUNCTION_NAME'] = original_func_name : ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    end
  end
end
