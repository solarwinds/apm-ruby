# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'SolarWindsOTLPProcessor' do
  before do
    SolarWindsAPM::OpenTelemetry::OTLPProcessor.prepend(DisableAddView)
    @txn_manager = SolarWindsAPM::TxnNameManager.new
    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(@txn_manager)
  end

  it 'initializes_metrics' do
    _(@processor.instance_variable_get(:@metrics).size).must_equal 1
  end

  it 'does_not_have_transaction_manager' do
    # currently otlp processor is only used in lambda which does not support transaction naming via SDK
    # this assumption may change when we introduce otlp export for non-lambda environments
    assert(@processor.txn_manager)
  end

  it 'test_calculate_span_time' do
    span_data = create_span_data

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp,
                                                   end_time: span_data.end_timestamp)
    _(result).must_equal 44_853

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp, end_time: nil)
    _(result).must_equal 0

    result = @processor.send(:calculate_span_time, start_time: nil, end_time: span_data.end_timestamp)
    _(result).must_equal 0
  end

  it 'test_calculate_transaction_names' do
    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'name'
  end

  it 'test_calculate_transaction_names_with_SW_APM_TRANSACTION_NAME' do
    ENV['SW_APM_TRANSACTION_NAME'] = 'another_name'

    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'another_name'
    ENV.delete('SW_APM_TRANSACTION_NAME')
  end

  it 'test_calculate_transaction_names_with_SW_APM_TRANSACTION_NAME_nil' do
    ENV['SW_APM_TRANSACTION_NAME'] = nil

    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal 'name'
  end

  it 'test_get_http_status_code' do
    span_data = create_span_data
    result = @processor.send(:get_http_status_code, span_data)
    _(result).must_equal 0

    span_data.attributes['http.status_code'] = 200
    result = @processor.send(:get_http_status_code, span_data)
    _(result).must_equal 200
  end

  it 'test_error?' do
    span_data = create_span_data
    result = @processor.send(:error?, span_data)
    _(result).must_equal 0
  end

  it 'test_span_http?' do
    span_data = create_span_data
    result = @processor.send(:span_http?, span_data)
    _(result).must_equal false
  end

  it 'test_on_start' do
    span = create_span
    processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(@txn_manager)
    processor.on_start(span, OpenTelemetry::Context.current)
    _(processor.txn_manager.get_root_context_h('77cb6ccc522d3106114dd6ecbb70036a')).must_equal '31e175128efc4018-00'
  end

  describe 'HTTP semantic convention tests' do
    it 'test_get_http_status_code_with_new_semantic_convention' do
      span_data = create_span_data
      span_data.attributes['http.response.status_code'] = 201
      result = @processor.send(:get_http_status_code, span_data)
      _(result).must_equal 201
    end

    it 'test_span_http_with_old_http_method' do
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

    it 'test_span_http_with_new_http_request_method' do
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

    it 'test_span_http_with_both_old_and_new_conventions' do
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

    it 'test_span_http_returns_false_for_non_server_span' do
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

    it 'test_meter_attributes_with_old_http_method' do
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

    it 'test_meter_attributes_with_new_http_request_method' do
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

    it 'test_meter_attributes_with_new_and_old_status_code_as_same_code' do
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

    it 'test_meter_attributes_with_new_and_old_status_code_as_different_code' do
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
      _(result['http.status_code']).must_equal 200
      _(result['sw.transaction']).must_equal 'test_transaction'
      _(result['sw.is_error']).must_equal false
    end

    it 'test_meter_attributes_non_http_span' do
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
end
