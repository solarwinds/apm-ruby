# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/support/logger_formatter'

describe 'Logger::Formatter trace ID injection, deduplication, and message edge cases' do
  before do
    @formatter = Logger::Formatter.new
  end

  it 'passes through when log_traceId is :never' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :never

    output = @formatter.call('INFO', Time.now, 'TestProg', 'test message')
    refute_nil output
    refute_includes output, 'trace_id='
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'inserts trace_id into string message when log_traceId is :always' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    output = @formatter.call('INFO', Time.now, 'TestProg', 'hello world')
    refute_nil output
    assert_includes output, 'trace_id='
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'does not duplicate trace_id if already present' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    msg = 'message trace_id=abc123'
    output = @formatter.call('INFO', Time.now, 'TestProg', msg)
    refute_nil output
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'skips empty messages' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    output = @formatter.call('INFO', Time.now, 'TestProg', '   ')
    refute_nil output
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'handles string message with error-like content' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    output = @formatter.call('ERROR', Time.now, 'TestProg', 'test error (StandardError)')
    refute_nil output
    assert_includes output, 'trace_id='
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'preserves trailing newlines in message' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    output = @formatter.call('INFO', Time.now, 'TestProg', "hello\n\n")
    refute_nil output
    assert_includes output, 'trace_id='
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end
end
