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
end
