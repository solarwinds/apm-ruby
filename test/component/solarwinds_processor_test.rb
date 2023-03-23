# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsProcessor' do
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
    exporter = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager:txn_name_manager)                                    
    @processor = SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor.new(exporter, txn_name_manager)
                                                
  end

  
  it 'test calculate_span_time' do 
    result = @processor.send(:calculate_span_time, start_time: @span_data.start_timestamp, end_time: @span_data.end_timestamp)
    _(result).must_equal 44853

    result = @processor.send(:calculate_span_time, start_time: @span_data.start_timestamp, end_time: nil)
    _(result).must_equal 0

    result = @processor.send(:calculate_span_time, start_time: nil, end_time: @span_data.end_timestamp)
    _(result).must_equal 0
  end

  it 'test calculate_transaction_names' do 
    result = @processor.send(:calculate_transaction_names, @span_data)
    _(result).must_equal "connect"
  end

  it 'test get_http_status_code' do 
    result = @processor.send(:get_http_status_code, @span_data)
    _(result).must_equal 0

    @span_data.attributes["http.status_code"] = 200
    result = @processor.send(:get_http_status_code, @span_data)
    _(result).must_equal 200
  end

  it 'test error?' do 
    result = @processor.send(:error?, @span_data)
    _(result).must_equal 0 
  end

  it 'test span_http?' do 
    result = @processor.send(:span_http?, @span_data)
    _(result).must_equal false 
  end


end
