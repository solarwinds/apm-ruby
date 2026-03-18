# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/settings'

describe 'SolarWindsAPM SamplingSettings Merge Test' do
  describe 'merge' do
    describe 'OVERRIDE is unset' do
      it 'respects tracing mode NEVER & trigger mode disabled' do
        remote = {
          sampling_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          tracing_mode: SolarWindsAPM::TracingMode::NEVER,
          trigger_mode: :disabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({ flags: 0x0 }, merged.slice(:flags))
      end

      it 'respects tracing mode ALWAYS & trigger mode enabled' do
        remote = {
          sample_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          tracing_mode: SolarWindsAPM::TracingMode::ALWAYS,
          trigger_mode: :enabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({
                       flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS | SolarWindsAPM::Flags::TRIGGERED_TRACE
                     }, merged.slice(:flags))
      end

      it 'defaults to remote value when local is unset' do
        remote = {
          sample_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          trigger_mode: :enabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end
    end

    describe 'OVERRIDE is set' do
      it 'respects tracing mode NEVER & trigger mode disabled' do
        remote = {
          sample_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::OVERRIDE | SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          tracing_mode: SolarWindsAPM::TracingMode::NEVER,
          trigger_mode: :disabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({ flags: SolarWindsAPM::Flags::OVERRIDE }, merged.slice(:flags))
      end

      it 'does not respect tracing mode ALWAYS & trigger mode enabled' do
        remote = {
          sample_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::OVERRIDE,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          tracing_mode: SolarWindsAPM::TracingMode::ALWAYS,
          trigger_mode: :enabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end

      it 'defaults to remote value when local is unset' do
        remote = {
          sample_rate: 1,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::OVERRIDE,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 60
        }
        local = {
          trigger_mode: :disabled
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end
    end
  end

  describe 'merge additional' do
    it 'merges remote and local settings with trigger mode enabled' do
      remote = {
        sample_rate: 500_000,
        sample_source: SolarWindsAPM::SampleSource::REMOTE,
        flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
        timestamp: Time.now.to_i,
        ttl: 120
      }
      local = { tracing_mode: nil, trigger_mode: :enabled }

      result = SolarWindsAPM::SamplingSettings.merge(remote, local)
      assert result[:flags].anybits?(SolarWindsAPM::Flags::TRIGGERED_TRACE)
    end

    it 'merges remote and local settings with trigger mode disabled' do
      remote = {
        sample_rate: 500_000,
        flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
        timestamp: Time.now.to_i,
        ttl: 120
      }
      local = { tracing_mode: nil, trigger_mode: :disabled }

      result = SolarWindsAPM::SamplingSettings.merge(remote, local)
      refute result[:flags].anybits?(SolarWindsAPM::Flags::TRIGGERED_TRACE)
    end

    it 'applies OVERRIDE flag from remote' do
      remote = {
        sample_rate: 500_000,
        flags: SolarWindsAPM::Flags::OVERRIDE | SolarWindsAPM::Flags::SAMPLE_START,
        timestamp: Time.now.to_i,
        ttl: 120
      }
      local = {
        tracing_mode: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
        trigger_mode: nil
      }

      result = SolarWindsAPM::SamplingSettings.merge(remote, local)
      assert result[:flags].anybits?(SolarWindsAPM::Flags::OVERRIDE)
    end

    it 'uses local tracing_mode when provided' do
      remote = {
        sample_rate: 500_000,
        flags: SolarWindsAPM::Flags::SAMPLE_START,
        timestamp: Time.now.to_i,
        ttl: 120
      }
      local = { tracing_mode: SolarWindsAPM::TracingMode::NEVER, trigger_mode: nil }

      result = SolarWindsAPM::SamplingSettings.merge(remote, local)
      assert_equal SolarWindsAPM::TracingMode::NEVER, result[:flags]
    end

    it 'uses remote flags when local tracing_mode is nil' do
      remote = {
        sample_rate: 500_000,
        flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
        timestamp: Time.now.to_i,
        ttl: 120
      }
      local = { tracing_mode: nil, trigger_mode: nil }

      result = SolarWindsAPM::SamplingSettings.merge(remote, local)
      assert result[:flags].anybits?(SolarWindsAPM::Flags::SAMPLE_START)
      assert result[:flags].anybits?(SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS)
    end
  end

  describe 'SpanType' do
    it 'returns ROOT for nil parent span context' do
      result = SolarWindsAPM::SpanType.span_type(nil)
      assert_equal SolarWindsAPM::SpanType::ROOT, result
    end

    it 'returns ROOT for invalid span context' do
      span = OpenTelemetry::Trace::Span::INVALID
      result = SolarWindsAPM::SpanType.span_type(span)
      assert_equal SolarWindsAPM::SpanType::ROOT, result
    end

    it 'returns ENTRY for remote span context' do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: Random.bytes(8),
        trace_id: Random.bytes(16),
        remote: true,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      result = SolarWindsAPM::SpanType.span_type(span)
      assert_equal SolarWindsAPM::SpanType::ENTRY, result
    end

    it 'returns LOCAL for non-remote valid span context' do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: Random.bytes(8),
        trace_id: Random.bytes(16),
        remote: false,
        trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED
      )
      span = OpenTelemetry::Trace.non_recording_span(span_context)
      result = SolarWindsAPM::SpanType.span_type(span)
      assert_equal SolarWindsAPM::SpanType::LOCAL, result
    end

    it 'valid_trace_id? returns true for valid ids' do
      assert SolarWindsAPM::SpanType.valid_trace_id?('a' * 32)
      assert SolarWindsAPM::SpanType.valid_trace_id?('0123456789abcdef' * 2)
    end

    it 'valid_trace_id? returns false for invalid ids' do
      refute SolarWindsAPM::SpanType.valid_trace_id?('0' * 32)
      refute SolarWindsAPM::SpanType.valid_trace_id?('xyz')
      refute SolarWindsAPM::SpanType.valid_trace_id?('short')
    end

    it 'valid_span_id? returns true for valid ids' do
      assert SolarWindsAPM::SpanType.valid_span_id?('a' * 16)
    end

    it 'valid_span_id? returns false for invalid ids' do
      refute SolarWindsAPM::SpanType.valid_span_id?('0' * 16)
      refute SolarWindsAPM::SpanType.valid_span_id?('xyz')
    end

    it 'span_context_valid? checks both trace_id and span_id' do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: Random.bytes(8),
        trace_id: Random.bytes(16)
      )
      assert SolarWindsAPM::SpanType.span_context_valid?(span_context)
    end
  end

  describe 'Structs' do
    it 'TriggerTraceOptions has the right members' do
      opts = SolarWindsAPM::TriggerTraceOptions.new(true, 12345, 'keys', {}, [], nil)
      assert opts.trigger_trace
      assert_equal 12345, opts.timestamp
      assert_equal 'keys', opts.sw_keys
    end

    it 'TraceOptionsResponse has the right members' do
      resp = SolarWindsAPM::TraceOptionsResponse.new('ok', 'ok', %w[a b])
      assert_equal 'ok', resp.auth
      assert_equal 'ok', resp.trigger_trace
      assert_equal %w[a b], resp.ignored
    end

    it 'TokenBucketSettings has defaults' do
      tbs = SolarWindsAPM::TokenBucketSettings.new(nil, nil, 'DEFAULT')
      assert_nil tbs.capacity
      assert_nil tbs.rate
      assert_equal 'DEFAULT', tbs.type
    end

    it 'SampleState struct works' do
      state = SolarWindsAPM::SampleState.new(:drop, {}, {}, {}, 'sw=abc', {}, nil)
      assert_equal :drop, state.decision
      assert_equal 'sw=abc', state.trace_state
    end
  end
end
