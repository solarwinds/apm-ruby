# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/trace_options'
require 'sampling_test_helper'
require 'openssl'
require 'securerandom'

describe 'parseTraceOptions' do
  let(:logger) { Logger.new($STDOUT) }

  it 'returns empty custom and ignored keys for bare equals sign' do
    header = '='
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)
    assert_equal({}, result.custom)
    _(result.ignored).must_equal []
  end

  it 'ignores value without a key prefix' do
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

  it 'parses trigger-trace flag with no value' do
    header = 'trigger-trace=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [%w[trigger-trace value]]
  end

  it 'keeps first trigger-trace and ignores duplicate' do
    header = 'trigger-trace;trigger-trace'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['trigger-trace', nil]]
  end

  it 'ignores ts key when it has no value' do
    header = 'ts'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', nil]]
  end

  it 'keeps first timestamp and ignores duplicate' do
    header = 'ts=1234;ts=5678'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.timestamp).must_equal(1234)
    assert_equal({}, result.custom)
    _(result.ignored).must_equal [%w[ts 5678]]
  end

  it 'ignores non-integer timestamp value' do
    header = 'ts=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [%w[ts value]]
  end

  it 'ignores float timestamp as non-integer' do
    header = 'ts=12.34'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['ts', '12.34']]
  end

  it 'trims whitespace from timestamp value' do
    header = 'ts = 1234567890 '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.timestamp).must_equal 1_234_567_890
    _(result.ignored).must_equal []
  end

  it 'ignores sw-keys when it has no value' do
    header = 'sw-keys'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['sw-keys', nil]]
  end

  it 'keeps first sw-keys and ignores duplicate' do
    header = 'sw-keys=keys1;sw-keys=keys2'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'keys1'
    _(result.ignored).must_equal [%w[sw-keys keys2]]
  end

  it 'trims whitespace from sw-keys value' do
    header = 'sw-keys= name:value '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'name:value'
    _(result.ignored).must_equal []
  end

  it 'splits sw-keys value at semicolon boundary' do
    header = 'sw-keys=check-id:check-1013,website-id;booking-demo'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.sw_keys).must_equal 'check-id:check-1013,website-id'
    _(result.ignored).must_equal [['booking-demo', nil]]
  end

  it 'trims whitespace from custom key values' do
    header = 'custom-key= value '
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'value'
    _(result.ignored).must_equal []
  end

  it 'ignores custom key without a value' do
    header = 'custom-key'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['custom-key', nil]]
  end

  it 'keeps first custom key and ignores duplicate' do
    header = 'custom-key=value1;custom-key=value2'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'value1'
    _(result.ignored).must_equal [%w[custom-key value2]]
  end

  it 'preserves equals sign within custom key value' do
    header = 'custom-key=name=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.custom['custom-key']).must_equal 'name=value'
    _(result.ignored).must_equal []
  end

  it 'rejects custom keys with spaces in the key name' do
    header = 'custom- key=value;custom-ke y=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [['custom- key', 'value'], ['custom-ke y', 'value']]
  end

  it 'ignores unknown non-custom non-reserved keys' do
    header = 'key=value'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert_equal({}, result.custom)
    _(result.ignored).must_equal [%w[key value]]
  end

  it 'trims whitespace from all option types in a complex header' do
    header = 'trigger-trace ; custom-something=value; custom-OtherThing = other val ; sw-keys = 029734wr70:9wqj21,0d9j1 ; ts = 12345 ; foo = bar'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal '029734wr70:9wqj21,0d9j1'
    _(result.timestamp).must_equal 12_345
    _(result.custom['custom-something']).must_equal 'value'
    _(result.custom['custom-OtherThing']).must_equal 'other val'
    _(result.ignored).must_equal [%w[foo bar]]
  end

  it 'handles multiple consecutive semicolons gracefully' do
    header = ';foo=bar;;;custom-something=value_thing;;sw-keys=02973r70:1b2a3;;;;custom-key=val;ts=12345;;;;;;;trigger-trace;;;'
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal '02973r70:1b2a3'
    _(result.timestamp).must_equal 12_345
    _(result.custom['custom-something']).must_equal 'value_thing'
    _(result.custom['custom-key']).must_equal 'val'
    _(result.ignored).must_equal [%w[foo bar]]
  end

  it 'splits on semicolons inside single-quoted custom values' do
    header = "trigger-trace;custom-foo='bar;bar';custom-bar=foo"
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.custom['custom-foo']).must_equal "'bar"
    _(result.custom['custom-bar']).must_equal 'foo'
    _(result.ignored).must_equal [["bar'", nil]]
  end

  it 'ignores entries with missing keys between semicolons' do
    header = ';trigger-trace;custom-something=value_thing;sw-keys=02973r70:9wqj21,0d9j1;1;2;3;4;5;=custom-key=val?;='
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    _(result.trigger_trace).must_equal true
    _(result.sw_keys).must_equal '02973r70:9wqj21,0d9j1'
    _(result.custom['custom-something']).must_equal 'value_thing'
    _(result.ignored).must_equal [['1', nil], ['2', nil], ['3', nil], ['4', nil], ['5', nil]]
  end

  it 'parses all option types in single header' do
    header = "trigger-trace;sw-keys=check-id:123;custom-foo=bar;ts=#{Time.now.to_i}"
    result = SolarWindsAPM::TraceOptions.parse_trace_options(header, logger)

    assert result.trigger_trace
    assert_equal 'check-id:123', result.sw_keys
    assert_equal 'bar', result.custom['custom-foo']
    refute_nil result.timestamp
  end
end

describe 'stringifyTraceOptionsResponse' do
  it 'formats auth and trigger-trace status into semicolon-delimited string' do
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(SolarWindsAPM::TraceOptionsResponse.new(SolarWindsAPM::Auth::OK, SolarWindsAPM::TriggerTrace::OK, []))
    _(result).must_equal('auth:ok;trigger-trace:ok')
  end

  it 'appends ignored keys to the response string' do
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(SolarWindsAPM::TraceOptionsResponse.new(SolarWindsAPM::Auth::OK, SolarWindsAPM::TriggerTrace::TRIGGER_TRACING_DISABLED, %w[invalid-key1 invalid_key2]))
    _(result).must_equal('auth:ok;trigger-trace:trigger-tracing-disabled;ignored:invalid-key1,invalid_key2')
  end

  it 'returns nil for nil response' do
    assert_nil SolarWindsAPM::TraceOptions.stringify_trace_options_response(nil)
  end

  it 'omits nil fields' do
    response = SolarWindsAPM::TraceOptionsResponse.new(nil, 'ok', [])
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(response)
    refute_includes result, 'auth'
    assert_includes result, 'trigger-trace:ok'
  end

  it 'returns empty string when all nil and empty' do
    response = SolarWindsAPM::TraceOptionsResponse.new(nil, nil, [])
    result = SolarWindsAPM::TraceOptions.stringify_trace_options_response(response)
    assert_equal '', result
  end
end

describe 'validateSignature' do
  it 'returns OK for valid HMAC signature within time window' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 60)
    _(result).must_equal(SolarWindsAPM::Auth::OK)
  end

  it 'returns BAD_SIGNATURE for tampered signature' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59d', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 60)
    _(result).must_equal(SolarWindsAPM::Auth::BAD_SIGNATURE)
  end

  it 'returns NO_SIGNATURE_KEY when key is nil' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', nil, Time.now.to_i - 60)
    _(result).must_equal(SolarWindsAPM::Auth::NO_SIGNATURE_KEY)
  end

  it 'returns BAD_TIMESTAMP when timestamp is too far in the past' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i - 600)
    _(result).must_equal(SolarWindsAPM::Auth::BAD_TIMESTAMP)
  end

  it 'returns BAD_TIMESTAMP when timestamp is in the future' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, Time.now.to_i + 600)
    _(result).must_equal(SolarWindsAPM::Auth::BAD_TIMESTAMP)
  end

  it 'returns BAD_TIMESTAMP when timestamp is nil' do
    result = SolarWindsAPM::TraceOptions.validate_signature('trigger-trace;pd-keys=lo:se,check-id:123;ts=1564597681', '2c1c398c3e6be898f47f74bf74f035903b48b59c', '8mZ98ZnZhhggcsUmdMbS'.b, nil)
    _(result).must_equal(SolarWindsAPM::Auth::BAD_TIMESTAMP)
  end
end

describe 'numeric_integer?' do
  it 'returns true for valid integer strings' do
    assert SolarWindsAPM::TraceOptions.numeric_integer?('12345')
    assert SolarWindsAPM::TraceOptions.numeric_integer?('-1')
    assert SolarWindsAPM::TraceOptions.numeric_integer?('0')
  end

  it 'returns false for non-integer strings' do
    refute SolarWindsAPM::TraceOptions.numeric_integer?('abc')
    refute SolarWindsAPM::TraceOptions.numeric_integer?('12.34')
    refute SolarWindsAPM::TraceOptions.numeric_integer?('')
  end
end
