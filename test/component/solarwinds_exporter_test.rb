# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'net/http'

describe 'SolarWindsExporterTest' do
  before do
    
    # create sample span
    status = ::OpenTelemetry::Trace::Status.ok("good") 
    attributes = {"net.peer.name"=>"sample-rails", "net.peer.port"=>8002}
    resource = ::OpenTelemetry::SDK::Resources::Resource.create({"service.name"=>"", "process.pid"=>31_208})
    instrumentation_scope = ::OpenTelemetry::SDK::InstrumentationScope.new("OpenTelemetry::Instrumentation::Net::HTTP", "1.2.3")
    trace_flags = ::OpenTelemetry::Trace::TraceFlags.from_byte(0x01)
    tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({"sw"=>"0000000000000000-01"})
    @span_data = ::OpenTelemetry::SDK::Trace::SpanData.new("connect",
                                                           :internal,
                                                           status,
                                                           ("\0" * 8).b,
                                                           2,
                                                           2,
                                                           0,
                                                           1_669_317_386_253_789_212,
                                                           1_669_317_386_298_642_087,
                                                           attributes,
                                                           nil,
                                                           nil,
                                                           resource,
                                                           instrumentation_scope,
                                                           "\xA4\xA49\x9D\xAC\xA5\x98\xC1",
                                                           "2\xC4^7zR\x8E\xC9\x16\x161\xF7\xF7X\xE1\xA7",
                                                           trace_flags,
                                                           tracestate)
    txn_name_manager = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new
    @exporter = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: txn_name_manager)
                                                
  end

  
  # Intergration test is to test the entire trace workflow from sampler to exporter
  # 1. instrument the net/http simple call (e.g. call https://www.google.com)
  # There will be two spans. 
  # a. The one is connect which contains 3 entries (i.e. entry, info, exit). 
  # b. The second one is HTTP GET, which contains 3 entries (i.e. entry, info, exit).
  it 'integration test' do 
    clear_all_traces
    Net::HTTP.get(URI('https://www.google.com'))
    traces = obtain_all_traces

    _(traces.count).must_equal 4

    _(traces[0]["TransactionName"]).must_equal "connect"
    _(traces[0]["Layer"]).must_equal "connect"
    _(traces[0]["sw.span_kind"]).must_equal "internal"
    _(traces[0]["Label"]).must_equal "entry"
    _(traces[0]["Timestamp_u"].to_s.length).must_equal 16
    _(traces[0]["sw.trace_context"].split("-").size).must_equal 4

    _(traces[1]["sw.trace_context"].split("-").size).must_equal 4
    _(traces[1]["Label"]).must_equal "exit"
    _(traces[1]["Layer"]).must_equal "connect"
    _(traces[1]["Edge"].size).must_equal 16
    _(traces[1]["Timestamp_u"].to_s.length).must_equal 16
    assert_equal(traces[0]["TID"], traces[1]["TID"])

    _(traces[2]["sw.trace_context"].split("-").size).must_equal 4
    _(traces[2]["TransactionName"]).must_equal "HTTP GET"
    _(traces[2]["Layer"]).must_equal "HTTP GET"
    _(traces[2]["sw.span_kind"]).must_equal "client"
    _(traces[2]["Language"]).must_equal "Ruby"
    _(traces[2]["Timestamp_u"].to_s.length).must_equal 16
    assert_equal(traces[0]["TID"], traces[2]["TID"])

    _(traces[3]["sw.trace_context"].split("-").size).must_equal 4
    _(traces[3]["Label"]).must_equal "exit"
    _(traces[3]["Layer"]).must_equal "HTTP GET"
    _(traces[3]["sw.parent_span_id"].size).must_equal 16
    _(traces[3]["Timestamp_u"].to_s.length).must_equal 16
    assert_equal(traces[0]["TID"], traces[3]["TID"])

  end

  it 'test build_meta_data false' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, parent: false)
    _(md.class.to_s).must_equal "Oboe_metal::Metadata"

  end

  it 'test build_meta_data true' do

    clear_all_traces
    md = @exporter.send(:build_meta_data, @span_data, parent: true)
    _(md.class.to_s).must_equal "Oboe_metal::Metadata"

  end

  it 'test report_exception_event' do

    Net::HTTP.get(URI('https://www.google.com'))
    clear_all_traces
    sample_events = ::OpenTelemetry::SDK::Trace::Event.new(name: "name", attributes: {"key" => "value"}.freeze, timestamp: 1_669_317_386_298_642_087)
    @exporter.send(:report_exception_event, sample_events)
    
    traces = obtain_all_traces

    _(traces.count).must_equal 1
    _(traces[0]["sw.trace_context"].empty?).must_equal false
    _(traces[0]["X-Trace"].empty?).must_equal false
    _(traces[0]["X-Trace"].size).must_equal 60
    _(traces[0]["sw.parent_span_id"].empty?).must_equal false
    _(traces[0]["Edge"].empty?).must_equal false
    _(traces[0]["Timestamp_u"]).must_equal 0
    _(traces[0]["Label"]).must_equal "error"
    _(traces[0]["Spec"]).must_equal "error"

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
    traces = obtain_all_traces

    _(traces.count).must_equal 2
    _(traces[0]["Label"]).must_equal "entry"
    _(traces[0]["Layer"]).must_equal "connect"
    _(traces[0]["sw.span_kind"]).must_equal "internal"
    _(traces[0]["Timestamp_u"]).must_equal 1_669_317_386_253_789

    _(traces[1]["Label"]).must_equal "exit"
    _(traces[1]["Timestamp_u"]).must_equal 1_669_317_386_298_642
    _(traces[1]["Layer"]).must_equal "connect"

  end
  

end
