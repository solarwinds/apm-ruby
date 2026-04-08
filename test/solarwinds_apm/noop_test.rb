# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/noop'

describe 'NoopAPI modules return safe defaults and no-op behavior' do
  # We need to test the noop modules individually since they're extended onto SolarWindsAPM::API
  # but during tests the real modules may be loaded

  describe 'NoopAPI::Tracing' do
    it 'solarwinds_ready? returns false' do
      obj = Object.new
      obj.extend(NoopAPI::Tracing)
      assert_equal false, obj.solarwinds_ready?
    end

    it 'solarwinds_ready? accepts integer_response parameter' do
      obj = Object.new
      obj.extend(NoopAPI::Tracing)
      assert_equal false, obj.solarwinds_ready?(5000, integer_response: true)
    end
  end

  describe 'NoopAPI::CurrentTraceInfo' do
    it 'current_trace_info returns TraceInfo' do
      obj = Object.new
      obj.extend(NoopAPI::CurrentTraceInfo)
      trace = obj.current_trace_info
      assert_equal '00000000000000000000000000000000', trace.trace_id
      assert_equal '0000000000000000', trace.span_id
      assert_equal '00', trace.trace_flags
      assert_equal '', trace.for_log
      assert_equal({}, trace.hash_for_log)
      assert_equal :never, trace.do_log
    end
  end

  describe 'NoopAPI::CustomMetrics' do
    it 'increment_metric returns false' do
      obj = Object.new
      obj.extend(NoopAPI::CustomMetrics)
      assert_equal false, obj.increment_metric('test')
    end

    it 'summary_metric returns false' do
      obj = Object.new
      obj.extend(NoopAPI::CustomMetrics)
      assert_equal false, obj.summary_metric('test', 1.0)
    end
  end

  describe 'NoopAPI::OpenTelemetry' do
    it 'in_span yields block' do
      obj = Object.new
      obj.extend(NoopAPI::OpenTelemetry)
      result = obj.in_span('test') { 42 }
      assert_equal 42, result
    end

    it 'in_span returns nil without block' do
      obj = Object.new
      obj.extend(NoopAPI::OpenTelemetry)
      result = obj.in_span('test')
      assert_nil result
    end
  end

  describe 'NoopAPI::TransactionName' do
    it 'set_transaction_name returns true' do
      obj = Object.new
      obj.extend(NoopAPI::TransactionName)
      assert_equal true, obj.set_transaction_name('test')
    end
  end

  describe 'NoopAPI::Tracer' do
    it 'add_tracer does nothing' do
      obj = Object.new
      obj.extend(NoopAPI::Tracer)
      result = obj.add_tracer(:foo, 'bar')
      assert_nil result
    end
  end
end
