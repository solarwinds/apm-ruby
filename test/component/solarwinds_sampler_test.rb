# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsSamplerTest' do
  before do

    sampler_config = Hash.new
    sampler_config["trigger_trace"] =  "enabled"
    @sampler = SolarWindsOTelAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config)
    @decision = Hash.new
    @attributes_dict = Hash.new
    @tracestate = ::OpenTelemetry::Trace::Tracestate.from_hash({})
    @parent_context = ::OpenTelemetry::Trace::SpanContext.new(span_id: "k1\xBF6\xB7k\xA7\x8B", trace_id: "H\x86\xC9\xC2\x16\xB2\xAA \xCE0@g\x81\xA1=P")
    @xtraceoptions  = SolarWindsOTelAPM::XTraceOptions.new(@parent_context)

  end

  it 'test init_context' do 
    context = @sampler.send(:init_context)
    assert_equal(context, SolarWindsOTelAPM::Context)
  end

  it 'test calculate_attributes' do 
    attributes = @sampler.send(:calculate_attributes, "tmp_span", @attributes_dict, @decision, @tracestate, @parent_context, @xtraceoptions)
    _(attributes["a"]).must_equal "b"
  end

  it 'test add_tracestate_capture_to_attributes_dict' do 
    attributes_dict = @sampler.send(:add_tracestate_capture_to_attributes_dict, @attributes_dict, @decision, @tracestate, @parent_context)
    _(attributes_dict["a"]).must_equal "b"
  end

  it 'test remove_response_from_sw' do 
    skip
  end

  it 'test calculate_trace_state' do 
    trace_state = @sampler.send(:calculate_trace_state, @decision, @parent_context, @xtraceoptions)
    _(trace_state.to_h.keys.size).must_equal 1
  end

  it 'test create_new_trace_state' do 
    trace_state = @sampler.send(:create_new_trace_state, @decision, @parent_context, @xtraceoptions)
    _(trace_state.to_h.keys.size).must_equal 1
  end

  it 'test create_xtraceoptions_response_value' do 
    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response[0]).must_equal ""
  end

  it 'test otel_decision_from_liboboe' do 
    @decision["do_metrics"]    = nil
    @decision["do_sample"]     = nil
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, ::OpenTelemetry::SDK::Trace::Samplers::Decision::DROP)

    @decision["do_metrics"]    = nil
    @decision["do_sample"]     = 1
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)

    @decision["do_metrics"]    = 1
    @decision["do_sample"]     = nil
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY)
  end

  it 'test calculate_liboboe_decision' do 
    
    decision = @sampler.send(:calculate_liboboe_decision, @parent_context, @xtraceoptions)
    _(decision).must_equal ""

  end

end
