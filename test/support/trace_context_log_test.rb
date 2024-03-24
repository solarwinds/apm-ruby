# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
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

  it 'test_logging_traceId_with_default' do
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
    logger = Logging.logger(@log_output)
    logger.level = :debug
    logger.debug "Sample debug message"
    @log_output.rewind
    refute_includes(@log_output.read, "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00")
  end

  it 'test_log_traceId_with_debug_always_valid_span' do
    SolarWindsAPM.logger.level = Logger::DEBUG
    SolarWindsAPM::Config[:log_traceId] = :sampled

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new))
    end

    OpenTelemetry.tracer_provider.tracer('my_service').in_span('sample_span') do |span|
      span.context.trace_flags.instance_variable_set(:@flags, 1)
      SolarWindsAPM.logger.debug "Sample debug message"
    end
    
    @log_output.rewind
    log_output = @log_output.read

    trace_id = log_output.match(/trace_id=([\da-fA-F]+)/)

    assert_equal(trace_id&.size, 2)
    assert_equal(trace_id[1]&.size, 32)

    span_id  = log_output.match(/span_id=([\da-fA-F]+)/)
    assert_equal(span_id&.size, 2)
    assert_equal(span_id[1]&.size, 16)

    trace_flags  = log_output.match(/trace_flags=([\da-fA-F]+)/)
    assert_equal(trace_flags&.size, 2)
    assert_equal(trace_flags[1]&.size, 2)
  end

  it 'test_log_traceId_with_debug_never_valid_span' do

    SolarWindsAPM.logger.level = Logger::DEBUG
    SolarWindsAPM::Config[:log_traceId] = :never

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new))
    end

    OpenTelemetry.tracer_provider.tracer('my_service').in_span('sample_span') do |_span|
      SolarWindsAPM.logger.debug "Sample debug message"
    end
    
    @log_output.rewind
    log_output = @log_output.read
    trace_id = log_output.match(/trace_id=([\da-fA-F]+)/)
    span_id  = log_output.match(/span_id=([\da-fA-F]+)/)
    trace_flags  = log_output.match(/trace_flags=([\da-fA-F]+)/)

    assert_nil(trace_id) 
    assert_nil(span_id)
    assert_nil(trace_flags)
  end

  it 'test_log_traceId_with_debug_never_valid_span_untraced' do

    SolarWindsAPM.logger.level = Logger::DEBUG
    SolarWindsAPM::Config[:log_traceId] = :sampled

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new))
    end

    OpenTelemetry.tracer_provider.tracer('my_service').in_span('sample_span') do |span|
      span.context.trace_flags.instance_variable_set(:@flags, 0) # force span to untraced so sampled won't append value
      SolarWindsAPM.logger.debug "Sample debug message"
    end
    
    @log_output.rewind
    log_output = @log_output.read
    trace_id = log_output.match(/trace_id=([\da-fA-F]+)/)
    span_id  = log_output.match(/span_id=([\da-fA-F]+)/)
    trace_flags  = log_output.match(/trace_flags=([\da-fA-F]+)/)

    assert_nil(trace_id) 
    assert_nil(span_id)
    assert_nil(trace_flags)
  end

  # lumberjack can't work in prepend Formatter anymore.
  # use logger.tag(context: lambda {SolarWindsAPM::API.current_trace_info.for_log})
  it 'test_lumberjack_with_tag_debug_sampled' do
    SolarWindsAPM::Config[:log_traceId] = :always
    logger = Lumberjack::Logger.new(@log_output, :level => :debug)
    logger.tag(tracecontext: -> {SolarWindsAPM::API.current_trace_info.for_log})
    logger.debug("Sample debug message")
    @log_output.rewind
    assert_includes @log_output.read, 'trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name='
  end

  it 'test_lumberjack_with_debug_sampled' do
    SolarWindsAPM::Config[:log_traceId] = :always
    logger = Lumberjack::Logger.new(@log_output, :level => :debug)
    logger.debug("Sample debug message")
    puts "@log_output: #{@log_output.string}"
    @log_output.rewind
    assert_includes @log_output.read, 'trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00 resource.service.name='
  end

  it 'test_lumberjack_with_debug_sampled_valid_span' do
    SolarWindsAPM::Config[:log_traceId] = :always
    logger = Lumberjack::Logger.new(@log_output, :level => :debug)

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new))
    end

    OpenTelemetry.tracer_provider.tracer('my_service').in_span('sample_span') do |span|
      span.context.trace_flags.instance_variable_set(:@flags, 1)
      logger.debug "Sample debug message"
    end

    @log_output.rewind
    log_output = @log_output.read

    trace_id = log_output.match(/trace_id=([\da-fA-F]+)/)

    assert_equal(trace_id&.size, 2)
    assert_equal(trace_id[1]&.size, 32)

    span_id  = log_output.match(/span_id=([\da-fA-F]+)/)
    assert_equal(span_id&.size, 2)
    assert_equal(span_id[1]&.size, 16)

    trace_flags  = log_output.match(/trace_flags=([\da-fA-F]+)/)
    assert_equal(trace_flags&.size, 2)
    assert_equal(trace_flags[1]&.size, 2)

    refute_includes(log_output, "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00")
  end
end
