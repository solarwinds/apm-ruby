# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'TransformerTest' do
  before do

    @span_context = ::OpenTelemetry::Trace::SpanContext.new(trace_id: "\xDD\x95\xC5l\xE3\x83\xCA\xF0\x95;S\x98i\xF9:{",
                                                            span_id: "\x8D\xB5\xDC?$l\x84W")

    @tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({"sw"=>"0000000000000000-01"})
    @transformer = SolarWindsOTelAPM::OpenTelemetry::Transformer
                                                
  end

  it 'test sw_from_context' do
    sw = @transformer.sw_from_context(@span_context)
    _(sw).must_equal "8db5dc3f246c8457-00"
  end

  it 'test trace_state_header' do
    result = @transformer.trace_state_header(@tracestate)
    _(result).must_equal "sw=0000000000000000-01"
  end

  it 'test traceparent_from_context' do 
    result = @transformer.traceparent_from_context(@span_context)
    _(result).must_equal "00-dd95c56ce383caf0953b539869f93a7b-8db5dc3f246c8457-00"
  end

  it 'test sw_from_span_and_decision' do 
    result = @transformer.sw_from_span_and_decision("a", "b")
    _(result).must_equal "a-b"
  end

  it 'test trace_flags_from_int' do 
    result = @transformer.trace_flags_from_int("0")
    _(result).must_equal "00"
  end

  it 'test is_sampled?' do 
    result = @transformer.is_sampled?(::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)
    _(result).must_equal true

    result = @transformer.is_sampled?(::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY)
    _(result).must_equal false
  end

  it 'test span_id_from_sw' do 
    result = @transformer.span_id_from_sw("a-b")
    _(result).must_equal "a"
  end

  it 'test get_current_span current-span' do 
    context_hash = Hash.new
    context_hash["current-span"] = "keys"
    context = OpenTelemetry::Context.new(context_hash)
    result = @transformer.get_current_span(context)
    _(result).must_equal "keys"
  end

  it 'test get_current_span last-span' do 
    context_hash = Hash.new
    context_hash["last-span"] = "keys"
    context = OpenTelemetry::Context.new(context_hash)
    result = @transformer.get_current_span(context)
    _(result.context.span_id).must_equal "\x00\x00\x00\x00\x00\x00\x00\x00"
  end

  it 'test create_key' do 
    result = @transformer.create_key("current-span")
    _(result.name).must_equal "current-span"
  end


end
