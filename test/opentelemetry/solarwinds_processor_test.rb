# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'SolarWindsProcessor' do
  before do
    @txn_name_manager = SolarWindsAPM::TxnNameManager.new
    @exporter = SolarWindsAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: @txn_name_manager)                                    
    @processor = SolarWindsAPM::OpenTelemetry::SolarWindsProcessor.new(@exporter, @txn_name_manager)                                             
  end

  it 'test_calculate_span_time' do
    span_data = create_span_data

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp, end_time: span_data.end_timestamp)
    _(result).must_equal 44_853

    result = @processor.send(:calculate_span_time, start_time: span_data.start_timestamp, end_time: nil)
    _(result).must_equal 0

    result = @processor.send(:calculate_span_time, start_time: nil, end_time: span_data.end_timestamp)
    _(result).must_equal 0
  end

  it 'test_calculate_transaction_names' do 
    span = create_span
    result = @processor.send(:calculate_transaction_names, span)
    _(result).must_equal "name"
  end

  it 'test_get_http_status_code' do 
    span_data = create_span_data
    result = @processor.send(:get_http_status_code, span_data)
    _(result).must_equal 0

    span_data.attributes["http.status_code"] = 200
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
    processor = SolarWindsAPM::OpenTelemetry::SolarWindsProcessor.new(@exporter, @txn_name_manager)
    processor.on_start(span, ::OpenTelemetry::Context.current)
    _(::OpenTelemetry::Baggage.value(::SolarWindsAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)).must_equal '77cb6ccc522d3106114dd6ecbb70036a'
    _(::OpenTelemetry::Baggage.value(::SolarWindsAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)).must_equal '31e175128efc4018'
  end
end
