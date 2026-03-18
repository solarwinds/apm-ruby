# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require 'opentelemetry-metrics-sdk'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/opentelemetry/otlp_processor'

describe 'SolarWindsOTLPProcessor' do
  before do
    SolarWindsAPM::OpenTelemetry::OTLPProcessor.prepend(DisableAddView)
    @txn_manager = SolarWindsAPM::TxnNameManager.new
    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(@txn_manager)
  end

  it 'initializes with exactly one metric instrument' do
    _(@processor.instance_variable_get(:@metrics).size).must_equal 1
  end

  it 'has a transaction manager instance after initialization' do
    # currently otlp processor is only used in lambda which does not support transaction naming via SDK
    # this assumption may change when we introduce otlp export for non-lambda environments
    assert(@processor.txn_manager)
  end

  it 'calculates span duration in microseconds and returns 0 for nil timestamps' do
    span_data = create_span_data

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp,
                                                   end_time: span_data.end_timestamp)
    _(result).must_equal 44_853

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp, end_time: nil)
    _(result).must_equal 0

    result = @processor.send(:calculate_span_time, start_time: nil, end_time: span_data.end_timestamp)
    _(result).must_equal 0
  end

  it 'returns the span name as the default transaction name' do
    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'name'
  end

  it 'returns SW_APM_TRANSACTION_NAME env var value when set' do
    ENV['SW_APM_TRANSACTION_NAME'] = 'another_name'

    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'another_name'
    ENV.delete('SW_APM_TRANSACTION_NAME')
  end

  it 'falls back to span name when SW_APM_TRANSACTION_NAME is nil' do
    ENV['SW_APM_TRANSACTION_NAME'] = nil

    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'name'
  end

  it 'returns 0 when no status code attribute exists and the value when present' do
    span_data = create_span_data
    result = @processor.send(:get_http_status_code, span_data)
    _(result).must_equal 0

    span_data.attributes['http.status_code'] = 200
    result = @processor.send(:get_http_status_code, span_data)
    _(result).must_equal 200
  end

  it 'returns 0 for a span with non-error status' do
    span_data = create_span_data
    result = @processor.send(:error?, span_data)
    _(result).must_equal 0
  end

  it 'returns false for a span without HTTP attributes' do
    span_data = create_span_data
    result = @processor.send(:span_http?, span_data)
    _(result).must_equal false
  end

  it 'stores root context in txn_manager when processing entry span' do
    span = create_span
    processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(@txn_manager)
    processor.on_start(span, OpenTelemetry::Context.current)
    _(processor.txn_manager.get_root_context_h('77cb6ccc522d3106114dd6ecbb70036a')).must_equal '31e175128efc4018-00'
  end

  describe 'HTTP semantic convention tests' do
    it 'returns status code from http.response.status_code attribute' do
      span_data = create_span_data
      span_data.attributes['http.response.status_code'] = 201
      result = @processor.send(:get_http_status_code, span_data)
      _(result).must_equal 201
    end

    it 'returns true for SERVER span with legacy http.method attribute' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.method' => 'GET' }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'GET /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data

      result = @processor.send(:span_http?, span_data)
      _(result).must_equal true
    end

    it 'returns true for SERVER span with http.request.method attribute' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.request.method' => 'POST' }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'POST /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data

      result = @processor.send(:span_http?, span_data)
      _(result).must_equal true
    end

    it 'returns true when both legacy and new HTTP method attributes are present' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.method' => 'GET', 'http.request.method' => 'POST' }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'GET /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data

      result = @processor.send(:span_http?, span_data)
      _(result).must_equal true
    end

    it 'returns false for CLIENT span even with HTTP attributes' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.request.method' => 'GET' }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'GET /users',
        OpenTelemetry::Trace::SpanKind::CLIENT,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data

      result = @processor.send(:span_http?, span_data)
      _(result).must_equal false
    end

    it 'builds meter attributes using legacy http.method and http.status_code' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.method' => 'GET', 'http.status_code' => 200 }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'GET /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data
      @processor.instance_variable_set(:@transaction_name, 'test_transaction')

      result = @processor.send(:meter_attributes, span_data)
      _(result['http.method']).must_equal 'GET'
      _(result['http.status_code']).must_equal 200
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end

    it 'builds meter attributes using http.request.method and http.response.status_code' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.request.method' => 'POST', 'http.response.status_code' => 201 }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'POST /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data
      @processor.instance_variable_set(:@transaction_name, 'test_transaction')

      result = @processor.send(:meter_attributes, span_data)
      _(result['http.method']).must_equal 'POST'
      _(result['http.status_code']).must_equal 201
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end

    it 'uses new status code when old and new status codes are identical' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.request.method' => 'POST', 'http.status_code' => 201, 'http.response.status_code' => 201 }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'POST /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data
      @processor.instance_variable_set(:@transaction_name, 'test_transaction')

      result = @processor.send(:meter_attributes, span_data)
      _(result['http.method']).must_equal 'POST'
      _(result['http.status_code']).must_equal 201
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end

    it 'prefers new http.response.status_code when old and new values differ' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = { 'http.request.method' => 'POST', 'http.status_code' => 200, 'http.response.status_code' => 201 }
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'POST /users',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data
      @processor.instance_variable_set(:@transaction_name, 'test_transaction')

      result = @processor.send(:meter_attributes, span_data)
      _(result['http.method']).must_equal 'POST'
      _(result['http.status_code']).must_equal 201
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end

    it 'excludes HTTP attributes from meter_attributes for non-HTTP spans' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new
      attributes = {}
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: "1\xE1u\x12\x8E\xFC@\x18",
        trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j"
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'database_query',
        OpenTelemetry::Trace::SpanKind::INTERNAL,
        nil,
        span_limits,
        [],
        attributes,
        nil,
        Time.now,
        nil,
        nil
      )
      span_data = span.to_span_data
      @processor.instance_variable_set(:@transaction_name, 'test_transaction')

      result = @processor.send(:span_http?, span_data)
      _(result).must_equal false

      result = @processor.send(:meter_attributes, span_data)
      _(result.key?('http.method')).must_equal false
      _(result.key?('http.status_code')).must_equal false
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end
  end

  describe 'force_flush' do
    it 'returns SUCCESS' do
      result = @processor.force_flush
      assert_equal ::OpenTelemetry::SDK::Trace::Export::SUCCESS, result
    end
  end

  describe 'shutdown' do
    it 'returns SUCCESS' do
      result = @processor.shutdown
      assert_equal ::OpenTelemetry::SDK::Trace::Export::SUCCESS, result
    end
  end

  describe 'txn_manager' do
    it 'returns the transaction name manager' do
      assert_equal @txn_manager, @processor.txn_manager
    end
  end

  describe 'on_start' do
    it 'does nothing for non-entry spans' do
      parent_span = create_span
      parent_context = OpenTelemetry::Trace.context_with_span(parent_span)

      span = create_span
      @processor.on_start(span, parent_context)

      # Non-entry span should not have sw.is_entry_span
      refute span.attributes&.key?('sw.is_entry_span')
    end

    it 'sets entry span attributes for root spans' do
      span_limits = OpenTelemetry::SDK::Trace::SpanLimits.new(attribute_count_limit: 10)
      span_context = OpenTelemetry::Trace::SpanContext.new(
        span_id: Random.bytes(8),
        trace_id: Random.bytes(16)
      )
      span = OpenTelemetry::SDK::Trace::Span.new(
        span_context,
        OpenTelemetry::Context.empty,
        OpenTelemetry::Trace::Span::INVALID,
        'test_entry',
        OpenTelemetry::Trace::SpanKind::SERVER,
        nil,
        span_limits,
        [],
        {},
        nil,
        Time.now,
        nil,
        nil
      )
      parent_context = OpenTelemetry::Context.empty

      @processor.on_start(span, parent_context)

      assert span.attributes['sw.is_entry_span']
    end

    it 'handles exceptions gracefully' do
      # Pass something that would cause an error
      span = create_span
      bad_context = nil

      # Should not raise, should handle gracefully
      @processor.on_start(span, bad_context)
    end
  end

  describe 'on_finish' do
    it 'does nothing for non-entry spans' do
      span_data = create_span_data
      # Does not raise
      @processor.on_finish(span_data)
    end
  end

  describe 'on_finishing' do
    it 'does nothing for non-entry spans' do
      span = create_span
      @processor.on_finishing(span)
    end
  end

  describe 'calculate_span_time' do
    it 'calculates time difference in microseconds' do
      result = @processor.send(:calculate_span_time, start_time: 1_000_000_000, end_time: 2_000_000_000)
      assert result > 0
    end
  end

  describe 'error?' do
    it 'returns 1 for error status' do
      span_data = create_span_data
      # Override status to error
      error_status = OpenTelemetry::Trace::Status.error('error')
      span_data_with_error = OpenTelemetry::SDK::Trace::SpanData.new(
        'test', :internal, error_status,
        ("\0" * 8).b, 2, 2, 0,
        1_669_317_386_253_789_212, 1_669_317_386_298_642_087,
        {}, nil, nil,
        OpenTelemetry::SDK::Resources::Resource.create({}),
        OpenTelemetry::SDK::InstrumentationScope.new('test', '1.0'),
        Random.bytes(8), Random.bytes(16),
        OpenTelemetry::Trace::TraceFlags.from_byte(0x01),
        OpenTelemetry::Trace::Tracestate::DEFAULT
      )

      result = @processor.send(:error?, span_data_with_error)
      assert_equal 1, result
    end
  end

  describe 'get_http_status_code additional' do
    it 'returns http.status_code fallback' do
      span_data = OpenTelemetry::SDK::Trace::SpanData.new(
        'test', :internal, OpenTelemetry::Trace::Status.ok,
        ("\0" * 8).b, 2, 2, 0,
        1_669_317_386_253_789_212, 1_669_317_386_298_642_087,
        { 'http.status_code' => 404 }, nil, nil,
        OpenTelemetry::SDK::Resources::Resource.create({}),
        OpenTelemetry::SDK::InstrumentationScope.new('test', '1.0'),
        Random.bytes(8), Random.bytes(16),
        OpenTelemetry::Trace::TraceFlags.from_byte(0x01),
        OpenTelemetry::Trace::Tracestate::DEFAULT
      )
      result = @processor.send(:get_http_status_code, span_data)
      assert_equal 404, result
    end

    describe 'non_entry_span' do
      it 'returns true for span without sw.is_entry_span' do
        span_data = create_span_data
        result = @processor.send(:non_entry_span, span: span_data)
        assert result
      end

      it 'returns false for parent context with invalid parent span' do
        context = OpenTelemetry::Context.empty
        result = @processor.send(:non_entry_span, parent_context: context)
        refute result
      end

      it 'returns true for local parent context' do
        parent_span = create_span
        parent_context = OpenTelemetry::Trace.context_with_span(parent_span)
        result = @processor.send(:non_entry_span, parent_context: parent_context)
        assert result
      end
    end

    describe 'calculate_transaction_names' do
      it 'uses txn_manager name when available' do
        span = create_span
        trace_span_id = "#{span.context.hex_trace_id}-#{span.context.hex_span_id}"
        @txn_manager.set(trace_span_id, 'custom_txn')

        result = @processor.send(:calculate_transaction_names, span)
        assert_equal 'custom_txn', result
      end

      it 'uses env var SW_APM_TRANSACTION_NAME when set' do
        ENV['SW_APM_TRANSACTION_NAME'] = 'env_txn_name'
        span = create_span

        result = @processor.send(:calculate_transaction_names, span)
        assert_equal 'env_txn_name', result
      ensure
        ENV.delete('SW_APM_TRANSACTION_NAME')
      end

      it 'uses http.route from span attributes' do
        span_context = OpenTelemetry::Trace::SpanContext.new(
          span_id: Random.bytes(8),
          trace_id: Random.bytes(16)
        )
        span = OpenTelemetry::SDK::Trace::Span.new(
          span_context,
          OpenTelemetry::Context.empty,
          OpenTelemetry::Trace::Span::INVALID,
          'default_name',
          OpenTelemetry::Trace::SpanKind::SERVER,
          nil,
          OpenTelemetry::SDK::Trace::SpanLimits.new,
          [],
          { 'http.route' => '/api/v1/users' },
          nil,
          Time.now,
          nil,
          nil
        )

        result = @processor.send(:calculate_transaction_names, span)
        assert_equal '/api/v1/users', result
      end

      it 'uses lambda transaction name in lambda mode' do
        @processor.instance_variable_set(:@is_lambda, true)
        ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-lambda'

        span = create_span
        result = @processor.send(:calculate_transaction_names, span)
        assert_equal 'my-lambda', result
      ensure
        @processor.instance_variable_set(:@is_lambda, false)
        ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
      end
    end

    describe 'calculate_lambda_transaction_name' do
      it 'uses SW_APM_TRANSACTION_NAME env var first' do
        ENV['SW_APM_TRANSACTION_NAME'] = 'custom_lambda'
        result = @processor.send(:calculate_lambda_transaction_name, 'span_name')
        assert_equal 'custom_lambda', result
      ensure
        ENV.delete('SW_APM_TRANSACTION_NAME')
      end

      it 'uses AWS_LAMBDA_FUNCTION_NAME when no custom name' do
        ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-lambda-func'
        result = @processor.send(:calculate_lambda_transaction_name, 'span_name')
        assert_equal 'my-lambda-func', result
      ensure
        ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
      end

      it 'falls back to span_name' do
        result = @processor.send(:calculate_lambda_transaction_name, 'the_span')
        assert_equal 'the_span', result
      end

      it 'falls back to unknown when no name' do
        result = @processor.send(:calculate_lambda_transaction_name, nil)
        assert_equal 'unknown', result
      end
    end

    describe 'meter_attributes' do
      it 'uses http.request.method over http.method' do
        @processor.instance_variable_set(:@transaction_name, 'test_txn')

        span_data = OpenTelemetry::SDK::Trace::SpanData.new(
          'test', :internal, OpenTelemetry::Trace::Status.ok,
          ("\0" * 8).b, 2, 2, 0,
          1_669_317_386_253_789_212, 1_669_317_386_298_642_087,
          { 'http.method' => 'GET', 'http.request.method' => 'POST', 'sw.is_entry_span' => true }, nil, nil,
          OpenTelemetry::SDK::Resources::Resource.create({}),
          OpenTelemetry::SDK::InstrumentationScope.new('test', '1.0'),
          Random.bytes(8), Random.bytes(16),
          OpenTelemetry::Trace::TraceFlags.from_byte(0x01),
          OpenTelemetry::Trace::Tracestate::DEFAULT
        )
        span_data.define_singleton_method(:kind) { ::OpenTelemetry::Trace::SpanKind::SERVER }

        result = @processor.send(:meter_attributes, span_data)
        assert_equal 'POST', result['http.method']
      end

      it 'omits http status code when 0' do
        @processor.instance_variable_set(:@transaction_name, 'test_txn')

        span_data = OpenTelemetry::SDK::Trace::SpanData.new(
          'test', :internal, OpenTelemetry::Trace::Status.ok,
          ("\0" * 8).b, 2, 2, 0,
          1_669_317_386_253_789_212, 1_669_317_386_298_642_087,
          { 'http.method' => 'GET', 'sw.is_entry_span' => true }, nil, nil,
          OpenTelemetry::SDK::Resources::Resource.create({}),
          OpenTelemetry::SDK::InstrumentationScope.new('test', '1.0'),
          Random.bytes(8), Random.bytes(16),
          OpenTelemetry::Trace::TraceFlags.from_byte(0x01),
          OpenTelemetry::Trace::Tracestate::DEFAULT
        )
        span_data.define_singleton_method(:kind) { ::OpenTelemetry::Trace::SpanKind::SERVER }

        result = @processor.send(:meter_attributes, span_data)
        refute result.key?('http.status_code')
      end
    end
  end
end
