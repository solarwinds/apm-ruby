# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require 'net/http'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/oboe_init_options'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/constants'

describe 'SolarWindsExporterTest' do
  before do
    txn_name_manager = SolarWindsAPM::OpenTelemetry::TxnNameManager.new
    @exporter = SolarWindsAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: txn_name_manager)
    SolarWindsAPM::Config[:log_args] = true                                     
  end

  it 'test_normalize_framework_name' do
    result = @exporter.send(:normalize_framework_name, 'net::http')
    _(result).must_equal 'net/http'

    result = @exporter.send(:normalize_framework_name, 'elasticsearch')
    _(result).must_equal 'elasticsearch'
  end

  it 'test_check_framework_version' do
    result = @exporter.send(:check_framework_version, 'opentelemetry-instrumentation-net_http')
    _(result.scan(/\d+.\d+.\d+/).length).must_equal 1

    result = @exporter.send(:check_framework_version, 'opentelemetry-instrumentation-bunny')
    _(result.scan(/\d+.\d+.\d+/).length).must_equal 1

    result = @exporter.send(:check_framework_version, 'opentelemetry-instrumentation-dummy')
    assert_nil(result)
  end

  it 'test_check_framework_version_with_version_cache' do
    @exporter.instance_variable_get(:@version_cache)['opentelemetry-instrumentation-net_http'] = '9.9.9'

    result = @exporter.send(:check_framework_version, 'opentelemetry-instrumentation-net_http')
    _(result).must_equal '9.9.9'

    @exporter.instance_variable_get(:@version_cache).delete('opentelemetry-instrumentation-net_http')
  end

  it 'test_build_meta_data' do
    span_data = create_span_data
    result = @exporter.send(:build_meta_data, span_data, parent: false)
    _(result).must_equal '00-00000000000000000000000000000000-0000000000000000-00'
  end

  it 'test_report_info_event' do
    span_event = ::OpenTelemetry::SDK::Trace::Event.new
    span_event.name='test'
    span_event.attributes={:test => 1}
    span_event.timestamp=1
    result = @exporter.send(:report_info_event, span_event)
    _(result).must_equal true
  end

  it 'test_report_exception_event' do
    span_event = ::OpenTelemetry::SDK::Trace::Event.new
    span_event.name='test'
    span_event.attributes={:test => 1}
    span_event.timestamp=1
    result = @exporter.send(:report_exception_event, span_event)
    _(result).must_equal true
  end

  it 'test_add_info_transaction_name' do
    span_data = create_span_data
    @exporter.instance_variable_get(:@txn_manager).set('32c45e377a528ec9161631f7f758e1a7-a4a4399daca598c1','solarwinds')
    result = @exporter.send(:add_info_transaction_name, span_data, SolarWindsAPM::Context)
    _(result).must_equal 'solarwinds'
  end

  it 'test_add_instrumented_framework' do
    span_data = create_span_data
    context   = SolarWindsAPM::Context.createEvent(10_000)
    result = @exporter.send(:add_instrumented_framework, context, span_data)
    assert_nil(result)   
  end

  it 'test_add_instrumentation_scope' do
    span_data = create_span_data
    context   = SolarWindsAPM::Context.createEvent(10_000)
    result = @exporter.send(:add_instrumentation_scope, context, span_data)
    assert_nil(result)
  end

  it 'test_log_span_data' do
    span_data = create_span_data
    result = @exporter.send(:log_span_data, span_data)
    _(result).must_equal true
  end

end
