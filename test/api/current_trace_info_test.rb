# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require_relative '../../lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'API::CurrentTraceInfo#for_log and #hash_for_log with log_traceId configuration' do
  describe 'TraceInfo' do
    it 'returns empty string for_log when log_traceId is :never' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :never

      trace = SolarWindsAPM::API.current_trace_info
      assert_equal '', trace.for_log
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns empty hash for hash_for_log when log_traceId is :never' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :never

      trace = SolarWindsAPM::API.current_trace_info
      assert_equal({}, trace.hash_for_log)
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns trace info for_log when log_traceId is :always' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :always

      trace = SolarWindsAPM::API.current_trace_info
      result = trace.for_log
      assert_includes result, 'trace_id='
      assert_includes result, 'span_id='
      assert_includes result, 'trace_flags='
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns hash for hash_for_log when log_traceId is :always' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :always

      trace = SolarWindsAPM::API.current_trace_info
      result = trace.hash_for_log
      assert result.key?('trace_id')
      assert result.key?('span_id')
      assert result.key?('trace_flags')
      assert result.key?('resource.service.name')
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns empty for_log when :traced and no active trace' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :traced

      trace = SolarWindsAPM::API.current_trace_info
      # Without an active trace, trace_id is all zeros, so valid? returns false
      assert_equal '', trace.for_log
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns empty for_log when :sampled and not sampled' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :sampled

      trace = SolarWindsAPM::API.current_trace_info
      # Without an active sampled trace, should return empty
      assert_equal '', trace.for_log
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns trace info within an active span for :traced' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :traced

      OpenTelemetry::SDK.configure
      tracer = OpenTelemetry.tracer_provider.tracer('test')
      tracer.in_span('test_span') do
        trace = SolarWindsAPM::API.current_trace_info
        result = trace.for_log
        assert_includes result, 'trace_id='
      end
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'returns trace info within a sampled span for :sampled' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :sampled

      OpenTelemetry::SDK.configure
      tracer = OpenTelemetry.tracer_provider.tracer('test')
      tracer.in_span('test_span') do
        trace = SolarWindsAPM::API.current_trace_info
        result = trace.for_log
        # The default sampler records & samples, so this should have trace info
        assert_includes result, 'trace_id='
      end
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'has boolean do_log attribute' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :always

      trace = SolarWindsAPM::API.current_trace_info
      assert trace.do_log
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end

    it 'has trace_id, span_id, trace_flags, tracestring attributes' do
      trace = SolarWindsAPM::API.current_trace_info
      refute_nil trace.trace_id
      refute_nil trace.span_id
      refute_nil trace.trace_flags
      refute_nil trace.tracestring
    end

    it 'for_log is memoized' do
      original = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :always

      trace = SolarWindsAPM::API.current_trace_info
      result1 = trace.for_log
      result2 = trace.for_log
      assert_equal result1, result2
    ensure
      SolarWindsAPM::Config[:log_traceId] = original
    end
  end
end
