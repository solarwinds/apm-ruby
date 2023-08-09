# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'lumberjack'
require 'logging'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/logger_formatter'
require './lib/solarwinds_apm/support/logging_log_event'
require './lib/solarwinds_apm/support/lumberjack_formatter'

describe 'Trace Context in Log Test' do

  before do
    @log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(@log_output)
  end

  after do
    SolarWindsAPM::Config[:log_traceId] = :never
    SolarWindsAPM.logger.level = Logger::INFO
  end

  it 'test_log_traceId_with_debug_always' do
    SolarWindsAPM.logger.level = Logger::DEBUG
    SolarWindsAPM::Config[:log_traceId] = :always
    SolarWindsAPM.logger.debug "Sample debug message"
    @log_output.rewind
    assert_includes @log_output.read, 'trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name='
  end

  it 'test_log_traceId_with_info_always' do
    SolarWindsAPM.logger.level = Logger::INFO
    SolarWindsAPM::Config[:log_traceId] = :always
    SolarWindsAPM.logger.debug "Sample debug message"
    @log_output.rewind
    assert_empty(@log_output.read)
  end

  it 'test_propagators_with_default' do
    SolarWindsAPM.logger.level = Logger::DEBUG
    SolarWindsAPM::Config[:log_traceId] = :sampled
    SolarWindsAPM.logger.debug "Sample debug message"
    @log_output.rewind
    refute_includes(@log_output.read, "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00")
  end

  it 'test_logging_traceId_with_debug_always' do
    SolarWindsAPM::Config[:log_traceId] = :always
    logger = Logging.logger(@log_output)
    logger.level = :debug
    logger.debug "Sample debug message"
    @log_output.rewind
    assert_includes @log_output.read, 'trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name='
  end

  it 'test_logging_traceId_with_debug_sampled' do
    SolarWindsAPM::Config[:log_traceId] = :sampled
    # log_output = StringIO.new
    logger = Logging.logger(@log_output)
    logger.level = :debug
    logger.debug "Sample debug message"
    @log_output.rewind
    refute_includes(@log_output.read, "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00")
  end

  # lumberjack can't work in prepend Formatter anymore.
  # use logger.tag(context: lambda {SolarWindsAPM::API.current_trace_info.for_log})
  it 'test_propagators_with_default' do
    SolarWindsAPM::Config[:log_traceId] = :always
    logger = Lumberjack::Logger.new(@log_output, :level => :debug)
    logger.tag(tracecontext: -> {SolarWindsAPM::API.current_trace_info.for_log})
    logger.debug("Sample debug message")
    @log_output.rewind
    assert_includes @log_output.read, 'trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name='
  end
end
