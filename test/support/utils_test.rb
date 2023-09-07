# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/utils'

describe 'Utility Test' do
  before do

    @span_context = ::OpenTelemetry::Trace::SpanContext.new(trace_id: "\xDD\x95\xC5l\xE3\x83\xCA\xF0\x95;S\x98i\xF9:{",
                                                            span_id: "\x8D\xB5\xDC?$l\x84W")

    @tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({"sw"=>"0000000000000000-01"})
    @utils = SolarWindsAPM::Utils
                                                
  end

  it 'test trace_state_header' do
    result = @utils.trace_state_header(@tracestate)
    _(result).must_equal "sw=0000000000000000-01"
  end

  it 'test traceparent_from_context' do 
    result = @utils.traceparent_from_context(@span_context)
    _(result).must_equal "00-dd95c56ce383caf0953b539869f93a7b-8db5dc3f246c8457-00"
  end
end
