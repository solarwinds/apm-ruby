# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require 'net/http'
require './lib/solarwinds_apm/opentelemetry'
# require './lib/solarwinds_apm/support/x_trace_options'
# require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/txn_name_manager'
# require './lib/solarwinds_apm/support/transformer'
# require './lib/solarwinds_apm/support/transaction_cache'
# require './lib/solarwinds_apm/support/transaction_settings'
# require './lib/solarwinds_apm/support/oboe_tracing_mode'
require './lib/solarwinds_apm/oboe_init_options'
require './lib/solarwinds_apm/config'
# require './lib/solarwinds_apm/api'

describe 'SolarWindsExporterTest' do
  before do
    
    # create sample span
    @status = ::OpenTelemetry::Trace::Status.ok("good") 
    @attributes = {"net.peer.name"=>"sample-rails", "net.peer.port"=>8002}
    @resource = ::OpenTelemetry::SDK::Resources::Resource.create({"service.name"=>"", "process.pid"=>31_208})
    @instrumentation_scope = ::OpenTelemetry::SDK::InstrumentationScope.new("OpenTelemetry::Instrumentation::Net::HTTP", "1.2.3")
    @trace_flags = ::OpenTelemetry::Trace::TraceFlags.from_byte(0x01)
    @tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({"sw"=>"0000000000000000-01"})

    create_span_data

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


  it 'test_add_info_instrumented_framework' do

  end

  it 'test_add_info_instrumentation_scope' do

  end

  it 'test_log_span_data' do

  end

  def create_span_data
    @span_data = ::OpenTelemetry::SDK::Trace::SpanData.new("connect",
                                                           :internal,
                                                           @status,
                                                           ("\0" * 8).b,
                                                           2,
                                                           2,
                                                           0,
                                                           1_669_317_386_253_789_212,
                                                           1_669_317_386_298_642_087,
                                                           @attributes,
                                                           nil,
                                                           nil,
                                                           @resource,
                                                           @instrumentation_scope,
                                                           "\xA4\xA49\x9D\xAC\xA5\x98\xC1",
                                                           "2\xC4^7zR\x8E\xC9\x16\x161\xF7\xF7X\xE1\xA7",
                                                           @trace_flags,
                                                           @tracestate)
  end

end
