# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/support/lumberjack_formatter'
require './lib/solarwinds_apm/support/logging_log_event'

describe 'Lumberjack::LogEntry trace ID injection based on log_traceId config' do
  it 'inserts trace id into lumberjack log entry when log_traceId is :always' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, 'test message', 'TestProg', Process.pid, nil)
    trace = SolarWindsAPM::API.current_trace_info
    expected_trace_info = trace.for_log
    assert_equal "test message #{expected_trace_info}", entry.message
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'does not insert trace id when log_traceId is :never' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :never

    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, 'test message', 'TestProg', Process.pid, nil)
    assert_equal 'test message', entry.message
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end
end

describe 'Logging::LogEvent trace ID injection based on log_traceId config' do
  it 'inserts trace id into logging log event when log_traceId is :always' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :always

    Logging.logger['test_logger']
    event = Logging::LogEvent.new('test_logger', Logging::LEVELS['info'], 'test log message', false)
    trace = SolarWindsAPM::API.current_trace_info
    expected_trace_info = trace.for_log
    assert_equal "test log message #{expected_trace_info}", event.data
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end

  it 'does not insert trace id when log_traceId is :never' do
    original = SolarWindsAPM::Config[:log_traceId]
    SolarWindsAPM::Config[:log_traceId] = :never

    event = Logging::LogEvent.new('test_logger', Logging::LEVELS['info'], 'test log message', false)
    assert_equal 'test log message', event.data
  ensure
    SolarWindsAPM::Config[:log_traceId] = original
  end
end
