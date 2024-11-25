# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/x_trace_options'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/support/transaction_cache'
require './lib/solarwinds_apm/support/transaction_settings'
require './lib/solarwinds_apm/support/oboe_tracing_mode'
require './lib/solarwinds_apm/config'

describe 'SolarWindsSamplerTest' do
  before do
    sampler_config = {}
    sampler_config['trigger_trace'] = :enabled
    @sampler = SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config)
    @decision = {}
    @attributes_dict = {}
    @attributes_dict['a'] = 'b'
    @tracestate = OpenTelemetry::Trace::Tracestate.from_hash({})
    @parent_context = OpenTelemetry::Trace::SpanContext.new(span_id: "k1\xBF6\xB7k\xA7\x8B",
                                                            trace_id: "H\x86\xC9\xC2\x16\xB2\xAA \xCE0@g\x81\xA1=P")

    context_value = {}
    context_value['sw_signature'] = 'sample_signature'
    context_value['sw_xtraceoptions'] = 'sample_xtraceoptions'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions = SolarWindsAPM::XTraceOptions.new(otel_context)
  end

  it 'test_calculate_attributes' do
    attributes = @sampler.send(:calculate_attributes, @attributes_dict, @decision, @tracestate, @parent_context,
                               @xtraceoptions)
    _(attributes['a']).must_equal 'b'
    _(attributes['BucketCapacity']).must_equal ''
    _(attributes['BucketRate']).must_equal ''
    _(attributes['SampleRate']).must_equal nil
    _(attributes['SampleSource']).must_equal nil
  end

  it 'test_add_tracestate_capture_to_new_attributes with sw.w3c.tracestate' do
    @attributes_dict['sw.w3c.tracestate'] = 'abc'
    attributes_dict = @sampler.send(:add_tracestate_capture_to_new_attributes, @attributes_dict, @decision,
                                    @tracestate, @parent_context)
    _(attributes_dict['a']).must_equal 'b'
  end

  it 'test_add_tracestate_capture_to_new_attributes' do
    attributes_dict = @sampler.send(:add_tracestate_capture_to_new_attributes, @attributes_dict, @decision,
                                    @tracestate, @parent_context)
    _(attributes_dict['a']).must_equal 'b'
  end

  it 'test_calculate_trace_state' do
    trace_state = @sampler.send(:calculate_trace_state, @decision, @parent_context, @xtraceoptions)

    _(trace_state.to_h.keys.size).must_equal 2
    _(trace_state.value('sw')).must_equal '6b31bf36b76ba78b-00'
    _(trace_state.value('xtrace_options_response')).must_equal 'trigger-trace####not-requested;ignored####sample_xtraceoptions'
  end

  it 'test_calculate_trace_state with parent_context contains different kv' do
    content = {}
    content['abc'] = 'cba'
    tracestate = OpenTelemetry::Trace::Tracestate.from_hash(content)
    parent_context = OpenTelemetry::Trace::SpanContext.new(span_id: "k1\xBF6\xB7k\xA7\x8B",
                                                           trace_id: "H\x86\xC9\xC2\x16\xB2\xAA \xCE0@g\x81\xA1=P",
                                                           tracestate: tracestate)
    trace_state = @sampler.send(:calculate_trace_state, @decision, parent_context, @xtraceoptions)

    _(trace_state.to_h.keys.size).must_equal 3
    _(trace_state.value('sw')).must_equal '6b31bf36b76ba78b-00'
    _(trace_state.value('abc')).must_equal 'cba'
    _(trace_state.value('xtrace_options_response')).must_equal 'trigger-trace####not-requested;ignored####sample_xtraceoptions'
  end

  it 'test_create_xtraceoptions_response_value default setting' do
    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'trigger-trace####not-requested;ignored####sample_xtraceoptions'
  end

  it 'test_create_xtraceoptions_response_value with empty otel_context xtraceoptions' do
    otel_context = OpenTelemetry::Context.new({})
    @xtraceoptions = SolarWindsAPM::XTraceOptions.new(otel_context)
    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'trigger-trace####not-requested'
  end

  it 'test_create_xtraceoptions_response_value with decision and sw_xtraceoptions setup' do
    @decision['status_msg'] = 'status'
    @decision['auth'] = 0

    context_value = {}
    context_value['sw_xtraceoptions'] = 'trigger-trace'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions = SolarWindsAPM::XTraceOptions.new(otel_context)

    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'trigger-trace####status'
  end

  it 'test_create_xtraceoptions_response_value with span_context valid and remote' do
    @decision['status_msg'] = 'status'
    @decision['auth'] = 0
    @decision['decision_type'] = 0

    context_value = {}
    context_value['sw_xtraceoptions'] = 'AAAabcdefg'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions  = SolarWindsAPM::XTraceOptions.new(otel_context)

    @parent_context = OpenTelemetry::Trace::SpanContext.new(span_id: "k1\xBF6\xB7k\xA7\x8B",
                                                            trace_id: "H\x86\xC9\xC2\x16\xB2\xAA \xCE0@g\x81\xA1=P", remote: true)

    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'trigger-trace####not-requested;ignored####AAAabcdefg'
  end

  it 'test_create_xtraceoptions_response_value with signature' do
    @decision['auth_msg'] = 'auth'

    context_value = {}
    context_value['sw_signature'] = 'signature_made'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions = SolarWindsAPM::XTraceOptions.new(otel_context)

    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'auth####auth;trigger-trace####not-requested'
  end

  it 'test_create_xtraceoptions_response_value without signature' do
    @decision['auth'] = nil

    context_value = {}
    context_value['sw_xtraceoptions'] = '1and1=candc'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions = SolarWindsAPM::XTraceOptions.new(otel_context)

    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)
    _(response).must_equal 'trigger-trace####not-requested;ignored####1and1'
  end

  it 'test_create_xtraceoptions_response_value with custom value' do
    @decision['status_msg'] = 'status'
    @decision['auth'] = 0
    @decision['decision_type'] = 1

    context_value = {}
    context_value['sw_xtraceoptions'] = 'sw-keys=hereiskeyyyy;trigger-trace;custom-key=12345'
    otel_context = OpenTelemetry::Context.new(context_value)
    @xtraceoptions  = SolarWindsAPM::XTraceOptions.new(otel_context)

    @parent_context = OpenTelemetry::Trace::SpanContext.new(span_id: "k1\xBF6\xB7k\xA7\x8B",
                                                            trace_id: "H\x86\xC9\xC2\x16\xB2\xAA \xCE0@g\x81\xA1=P", remote: true)

    response = @sampler.send(:create_xtraceoptions_response_value, @decision, @parent_context, @xtraceoptions)

    _(@xtraceoptions.sw_keys).must_equal 'hereiskeyyyy'
    _(@xtraceoptions.trigger_trace).must_equal true
    _(@xtraceoptions.custom_kvs['custom-key']).must_equal '12345'
    _(response).must_equal 'trigger-trace####status'
  end

  it 'test_otel_decision_from_liboboe' do
    @decision['do_metrics']    = nil
    @decision['do_sample']     = nil
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, OpenTelemetry::SDK::Trace::Samplers::Decision::DROP)

    @decision['do_metrics']    = nil
    @decision['do_sample']     = 1
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)

    @decision['do_metrics']    = 1
    @decision['do_sample']     = nil
    otel_decision = @sampler.send(:otel_decision_from_liboboe, @decision)
    assert_equal(otel_decision, OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY)
  end

  it 'test_calculate_liboboe_decision' do
    decision = @sampler.send(:calculate_liboboe_decision, @parent_context, @xtraceoptions, '', '', {})
    _(decision['do_metrics']).must_equal true
    _(decision['do_sample']).must_equal false
    _(decision['rate']).must_equal 1_000_000
    _(decision['status_msg']).must_equal 'auth-failed'
    _(decision['auth_msg']).must_equal 'bad-signature'
    _(decision['source']).must_equal 6
    _(decision['bucket_rate']).must_equal 0.0
    _(decision['status']).must_equal(-5)
  end

  it 'test_should_sample?' do
    should_sample = @sampler.send(:otel_sampled?, OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)
    assert(should_sample)

    should_sample = @sampler.send(:otel_sampled?, OpenTelemetry::SDK::Trace::Samplers::Decision::DROP)
    _(should_sample).must_equal false

    should_sample = @sampler.send(:otel_sampled?, OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY)
    _(should_sample).must_equal false
  end
end
