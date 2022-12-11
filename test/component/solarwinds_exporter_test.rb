# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsExporterTest' do
  before do
    
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
    @exporter = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(endpoint:"",metrics_reporter:nil,service_key:"",apm_txname_manager:txn_name_manager)
                                                
  end


  it 'integration test' do 

    clear_all_traces
    require 'net/http'
    Net::HTTP.get(URI('https://www.google.com'))
    traces = get_all_traces

    _(traces.count).must_equal 6

    _(traces[0]["TransactionName"]).must_equal "connect"
    _(traces[0]["Layer"]).must_equal "connect"
    _(traces[0]["Kind"]).must_equal "internal"
    _(traces[0]["Label"]).must_equal "entry"

    _(traces[1]["telemetry.sdk.name"]).must_equal "opentelemetry"
    _(traces[1]["Label"]).must_equal "info"

    _(traces[2]["Label"]).must_equal "exit"
    _(traces[2]["Layer"]).must_equal "connect"

    _(traces[3]["TransactionName"]).must_equal "HTTP GET"
    _(traces[3]["Layer"]).must_equal  "HTTP GET"
    _(traces[3]["Kind"]).must_equal  "client"

    _(traces[5]["Label"]).must_equal "exit"
    _(traces[5]["Layer"]).must_equal  "HTTP GET"

  end

  it 'test build_meta_data false' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, false)
    _(md.class.to_s).must_equal "Oboe_metal::Metadata"

  end

  it 'test build_meta_data true' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, true)
    _(md.class.to_s).must_equal "Oboe_metal::Metadata"

  end

  it 'test report_exception_event' do

    clear_all_traces
    @exporter.send(:report_exception_event, @span_data)
    traces = get_all_traces
    _(traces.count).must_equal 1

    _(traces[0]["Label"]).must_equal "error"
    _(traces[0]["Spec"]).must_equal "error"
    _(traces[0]["Edge"]).must_equal "0000000000000000"
    _(traces[0]["sw.trace_context"]).must_equal "00-32c45e377a528ec9161631f7f758e1a7-b785d34a4943817d-01"
    _(traces[0]["Timestamp_u"]).must_equal 1669317386298642
    _(traces[0]["Label"]).must_equal "entry"

  end

  # this add_info_transaction_name is not testable, need to make it testable
  it 'test add_info_transaction_name ' do

    clear_all_traces

    md = @exporter.send(:build_meta_data, @span_data)
    event = SolarWindsOTelAPM::Context.createEntry(md, (@span_data.start_timestamp.to_i / 1000).to_i)
    result = @exporter.send(:add_info_transaction_name, @span_data, event)
    _(result).must_equal nil

  end

  it 'test log_span_data ' do
    # this add_info_transaction_name is not testable, need to make it testable

    clear_all_traces
    @exporter.send(:log_span_data, @span_data)
    traces = get_all_traces

    _(traces.count).must_equal 3
    _(traces[0]["Label"]).must_equal "entry"
    _(traces[0]["Layer"]).must_equal "connect"
    _(traces[0]["Kind"]).must_equal "internal"
    _(traces[0]["Timestamp_u"]).must_equal 1669317386253789

    _(traces[1]["Label"]).must_equal "info"
    _(traces[1]["Timestamp_u"]).must_equal 1669317386298642

    _(traces[2]["Label"]).must_equal "exit"
    _(traces[2]["Timestamp_u"]).must_equal 1669317386298642
    _(traces[2]["Layer"]).must_equal "connect"

  end
  

end
