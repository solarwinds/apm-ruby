# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/trace_options_test.rb
# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/trace_options_test.rb -n /timestamp\ invalid/

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/trace_options'

describe 'parseTraceOptions' do

  let(:logger) { Logger.new($STDOUT) }

  it 'no key no value' do
    header = '='
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)
    assert_equal({}, result.custom)
    _(result.ignored).must_equal []
  end

  it 'orphan value' do
    header = '=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal []
  end

  it 'valid trigger trace' do
    header = 'trigger-trace'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    assert_equal({}, result.custom)
    _(result.ignored).must_equal []
  end

  it 'trigger trace no value' do
    header = 'trigger-trace=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['trigger-trace', 'value']]
  end
  
  it 'trigger trace duplicate' do
    header = 'trigger-trace;trigger-trace'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    puts result.inspect
    _(result.trigger_trace).must_equal true
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['trigger-trace', nil]]
  end

  it 'timestamp no value' do
    header = 'ts'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', nil]]
  end
  
  it 'timestamp duplicate' do
    header = 'ts=1234;ts=5678'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.timestamp).must_equal(1234)
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', '5678']]
  end
  
  it 'timestamp invalid' do
    header = 'ts=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', 'value']]
  end

  it 'timestamp float' do
    header = 'ts=12.34'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', '12.34']]
  end

  it 'timestamp trim' do
    header = 'ts = 1234567890 '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.timestamp).must_equal 1234567890
    _(result.ignored).must_equal []
  end

  it 'sw-keys no value' do
    header = 'sw-keys'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['sw-keys', nil]]
  end

  it 'sw-keys duplicate' do
    header = 'sw-keys=keys1;sw-keys=keys2'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'keys1'
    _(result.ignored).must_equal [['sw-keys', 'keys2']]
  end

  it 'sw-keys trim' do
    header = 'sw-keys= name:value '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'name:value'
    _(result.ignored).must_equal []
  end

  it 'sw-keys ignore after semi' do
    header = 'sw-keys=check-id:check-1013,website-id;booking-demo'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'check-id:check-1013,website-id'
    _(result.ignored).must_equal [['booking-demo', nil]]
  end

  it 'custom keys trim' do
    header = 'custom-key= value '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'value'
    _(result.ignored).must_equal []
  end

  it 'custom keys no value' do
    header = 'custom-key'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['custom-key', nil]]
  end

  it 'custom keys duplicate' do
    header = 'custom-key=value1;custom-key=value2'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'value1'
    _(result.ignored).must_equal [['custom-key', 'value2']]
  end

  it 'custom keys equals in value' do
    header = 'custom-key=name=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'name=value'
    _(result.ignored).must_equal []
  end

  it 'custom keys spaces in key' do
    header = 'custom- key=value;custom-ke y=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)
    
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['custom- key', 'value'], ['custom-ke y', 'value']]
  end

  it 'other ignored' do
    header = 'key=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)
    
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['key', 'value']]
  end

  it "trim everything" do
    header = "trigger-trace ; custom-something=value; custom-OtherThing = other val ; sw-keys = 029734wr70:9wqj21,0d9j1 ; ts = 12345 ; foo = bar"
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal "029734wr70:9wqj21,0d9j1"
    _(result.timestamp).must_equal 12345
    _(result.custom['custom-something']).must_equal 'value'
    _(result.custom['custom-OtherThing']).must_equal 'other val'
    _(result.ignored).must_equal [["foo", "bar"]]
  end

  it "semi everywhere" do
    header = ";foo=bar;;;custom-something=value_thing;;sw-keys=02973r70:1b2a3;;;;custom-key=val;ts=12345;;;;;;;trigger-trace;;;"
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal '02973r70:1b2a3'
    _(result.timestamp).must_equal 12345
    _(result.custom['custom-something']).must_equal 'value_thing'
    _(result.custom['custom-key']).must_equal 'val'
    _(result.ignored).must_equal [["foo", "bar"]]
  end

  it "single quotes" do
    header = "trigger-trace;custom-foo='bar;bar';custom-bar=foo"
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.custom['custom-foo']).must_equal "'bar"
    _(result.custom['custom-bar']).must_equal "foo"
    _(result.ignored).must_equal [["bar'", nil]]
  end

  it "missing values and semi" do
    header = ";trigger-trace;custom-something=value_thing;sw-keys=02973r70:9wqj21,0d9j1;1;2;3;4;5;=custom-key=val?;="
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)
    
    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal '02973r70:9wqj21,0d9j1'
    _(result.custom['custom-something']).must_equal 'value_thing'
    _(result.ignored).must_equal [["1", nil],["2", nil],["3", nil],["4", nil],["5", nil]]
  end
end

describe 'stringifyTraceOptionsResponse' do
  it 'basic' do
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(TraceOptionsResponse.new(Auth::OK, TriggerTrace::OK, []))
    _(result).must_equal('auth:ok;trigger-trace:ok')
  end
  
  it 'ignored values' do
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(TraceOptionsResponse.new(Auth::OK, TriggerTrace::TRIGGER_TRACING_DISABLED, ['invalid-key1', 'invalid_key2']))
    _(result).must_equal('auth:ok;trigger-trace:trigger-tracing-disabled;ignored:invalid-key1,invalid_key2')
  end
end

describe 'validateSignature' do
  it 'valid signature' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 60)
    _(result).must_equal(Auth::OK)
  end
  
  it 'invalid signature' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59d', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 60)
    _(result).must_equal(Auth::BAD_SIGNATURE)
  end
  
  it 'missing signature key' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', nil, Time.now.to_i - 60)
    _(result).must_equal(Auth::NO_SIGNATURE_KEY)
  end

  it 'timestamp past' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 600)
    _(result).must_equal(Auth::BAD_TIMESTAMP)
  end
  
  it 'timestamp future' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i + 600)
    _(result).must_equal(Auth::BAD_TIMESTAMP)
  end
  
  it 'missing timestamp' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, nil)
    _(result).must_equal(Auth::BAD_TIMESTAMP)
  end
end
