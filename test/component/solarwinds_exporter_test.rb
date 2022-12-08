# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsExporterTest' do
  before do
    # make sure these settings are
    # SW_APM_COLLECTOR: "/tmp/sw_apm_traces.bson"
    # SW_APM_REPORTER: "file"
    # SW_APM_REPORTER_FILE_SINGLE: "false"
    # set up this collector to file and file single works
    # require 'bson'
    # SolarWindsOTelAPM::Reporter.get_all_traces return traces
    # this is also good for integration and regression test

    # create sample span
    status = ::OpenTelemetry::Trace::Status.ok("good") 
    attributes = {"net.peer.name"=>"sample-rails", "net.peer.port"=>8002}
    resource = ::OpenTelemetry::SDK::Resources::Resource.create({"service.name"=>"", "process.pid"=>31208})
    instrumentation_scope = ::OpenTelemetry::SDK::InstrumentationScope.new("OpenTelemetry::Instrumentation::Net::HTTP", "1.2.3")
    instrumentation_library = ::OpenTelemetry::SDK::InstrumentationLibrary.new("OpenTelemetry::Instrumentation::Net::HTTP", "1.2.3")
    trace_flags = ::OpenTelemetry::Trace::TraceFlags.from_byte(0x01)
    tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({"sw"=>"0000000000000000-01"})
    @span_data = ::OpenTelemetry::SDK::Trace::SpanData.new("connect",
                                                            :internal,
                                                            status,
                                                            ("\0" * 8).b,
                                                            2,
                                                            2,
                                                            0,
                                                            1669317386253789212,
                                                            1669317386298642087,
                                                            attributes,
                                                            nil,
                                                            nil,
                                                            resource,
                                                            instrumentation_scope,
                                                            "\xA4\xA49\x9D\xAC\xA5\x98\xC1",
                                                            "2\xC4^7zR\x8E\xC9\x16\x161\xF7\xF7X\xE1\xA7",
                                                            trace_flags,
                                                            tracestate
                                                          )

    txn_name_manager = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new
    @exporter = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new("",nil,"",txn_name_manager)
                                                
  end


  it 'integration test' do 

    clear_all_traces
    require 'net/http'
    Net::HTTP.get(URI('https://www.google.com'))
    traces = get_all_traces

    _(traces.count).must_equal 4

    _(traces[1]['Layer']).must_equal 'faraday'
    _(traces[1].key?('Backtrace')).must_equal SolarWindsAPM::Config[:faraday][:collect_backtraces]
    _(traces[5]['Layer']).must_equal 'net-http'

  end

  it 'test build_meta_data false' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, false)
    _(md).must_equal "ab"

  end

  it 'test build_meta_data true' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, true)
    _(md).must_equal "ab"

  end


  it 'test report_exception_event' do

    clear_all_traces
    @exporter.send(:report_exception_event, @span_data)
    traces = get_all_traces

    _(traces.count).must_equal 4

  end


  it 'test add_info_transaction_name ' do
    # this add_info_transaction_name is not testable, need to make it testable

    clear_all_traces

    md = @exporter.send(:build_meta_data, @span_data)
    event = SolarWindsOTelAPM::Context.createEntry(md, (@span_data.start_timestamp.to_i / 1000).to_i)
    @exporter.send(:add_info_transaction_name, @span_data, event)

  end

  it 'test log_span_data ' do
    # this add_info_transaction_name is not testable, need to make it testable

    clear_all_traces
    @exporter.send(:log_span_data, @span_data)
    traces = get_all_traces

    _(traces.count).must_equal 4
  end

  
  
  
  
  
  
  
  
  

end
