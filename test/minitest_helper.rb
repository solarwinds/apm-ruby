# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/reporters'
require 'minitest'
require 'minitest/focus'
require 'minitest/debugger' if ENV['DEBUG']
require 'minitest/hooks/default' # adds after(:all)
require 'opentelemetry/sdk'
require 'opentelemetry-common'
require 'opentelemetry-api'
require 'opentelemetry-propagator-b3'
require 'opentelemetry-exporter-otlp'
require 'lumberjack'
require 'logging'
require 'bson'
require 'pp'

require './lib/solarwinds_apm/version'
require './lib/solarwinds_apm/logger'
require './lib/solarwinds_apm/constants'
require 'opentelemetry-exporter-otlp-metrics'

require 'simplecov'
SimpleCov.start

# needed by most tests
ENV['SW_APM_SERVICE_KEY'] = 'this-is-a-dummy-api-token-for-testing-111111111111111111111111111111111:test-service'
ENV['RACK_ENV'] = 'test'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

SolarWindsAPM.logger.level = 1

# Dummy Propagator for testing
module Dummy
  class TextMapPropagator
    def inject(carrier, context: ::OpenTelemetry::Context.current, setter: ::OpenTelemetry::Context::Propagation.text_map_setter); end

    def extract(carrier, context: ::OpenTelemetry::Context.current, getter: ::OpenTelemetry::Context::Propagation.text_map_getter); end
  end
end

# Dummy Exporter for testing
module Exporter
  class Dummy
    def flush(); end
  end
end

module SolarWindsAPM
  class << self
    attr_accessor :logger
  end
end

# for custom_metrics_test.rb
module SolarWindsAPM
  module CustomMetrics
    def self.increment; end

    def self.summary; end
  end
end

module SolarWindsAPM
  module MetricTags
    def self.new; end

    def self.add; end
  end
end

class CustomInMemorySpanExporter < OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter
  def finished_spans
    @finished_spans.clone.freeze
  end

  def export(span_datas)
    @finished_spans.concat(span_datas.to_a)
    ::OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end

##
# extract_span
#
# get finished_span from exporter that overcome time issue
#
def extract_span(exporter)
  finished_spans = []
  retry_count    = 5
  while finished_spans.empty?

    break if retry_count > 5

    finished_spans = exporter.finished_spans
    retry_count   += 1
    sleep retry_count
  end

  finished_spans
end

##
# create_span_data
#
# create sample otel span_data object
#
def create_span_data
  layer  = :internal
  status = OpenTelemetry::Trace::Status.ok('good')
  attributes = { 'net.peer.name' => 'sample-rails', 'net.peer.port' => 8002 }
  resource = OpenTelemetry::SDK::Resources::Resource.create({ 'service.name' => '', 'process.pid' => 31_208 })
  instrumentation_scope = OpenTelemetry::SDK::InstrumentationScope.new('OpenTelemetry::Instrumentation::Net::HTTP',
                                                                       '1.2.3')
  trace_flags  = OpenTelemetry::Trace::TraceFlags.from_byte(0x01)
  tracestate   = OpenTelemetry::Trace::Tracestate.from_hash({ 'sw' => '0000000000000000-01' })
  span_id_hex  = "\xA4\xA49\x9D\xAC\xA5\x98\xC1"
  trace_id_hex = "2\xC4^7zR\x8E\xC9\x16\x161\xF7\xF7X\xE1\xA7"

  OpenTelemetry::SDK::Trace::SpanData.new('connect',
                                          layer,
                                          status,
                                          ("\0" * 8).b,
                                          2,
                                          2,
                                          0,
                                          1_669_317_386_253_789_212,
                                          1_669_317_386_298_642_087,
                                          attributes,
                                          nil,
                                          nil,
                                          resource,
                                          instrumentation_scope,
                                          span_id_hex,
                                          trace_id_hex,
                                          trace_flags,
                                          tracestate)
end

##
# create_span
#
# create sample otel span object
#
def create_span
  span_limits  = OpenTelemetry::SDK::Trace::SpanLimits.new(attribute_count_limit: 1,
                                                           event_count_limit: 1,
                                                           link_count_limit: 1,
                                                           event_attribute_count_limit: 1,
                                                           link_attribute_count_limit: 1,
                                                           attribute_length_limit: 32,
                                                           event_attribute_length_limit: 32)
  attributes   = { 'net.peer.name' => 'sample-rails', 'net.peer.port' => 8002 }
  span_context = OpenTelemetry::Trace::SpanContext.new(span_id: "1\xE1u\x12\x8E\xFC@\x18",
                                                       trace_id: "w\xCBl\xCCR-1\x06\x11M\xD6\xEC\xBBp\x03j")
  OpenTelemetry::SDK::Trace::Span.new(span_context,
                                      OpenTelemetry::Context.empty,
                                      OpenTelemetry::Trace::Span::INVALID,
                                      'name',
                                      OpenTelemetry::Trace::SpanKind::INTERNAL,
                                      nil,
                                      span_limits,
                                      [],
                                      attributes,
                                      nil,
                                      Time.now,
                                      nil,
                                      nil)
end

##
# create_context
#
# create sample otel context
#
def create_context(trace_id:,
                   span_id:,
                   trace_flags: OpenTelemetry::Trace::TraceFlags::DEFAULT)
  context = OpenTelemetry::Trace.context_with_span(
    OpenTelemetry::Trace.non_recording_span(
      OpenTelemetry::Trace::SpanContext.new(
        trace_id: Array(trace_id).pack('H*'),
        span_id: Array(span_id).pack('H*'),
        trace_flags: trace_flags
      )
    )
  )
  conext_key = OpenTelemetry::Context.create_key('b3-debug-key')
  context.set_value(conext_key, true)
end

##
# clean_old_setting
#
# return to fresh new state for testing
#
def clean_old_setting
  ENV.delete('OTEL_PROPAGATORS')
  ENV.delete('OTEL_TRACES_EXPORTER')
  ENV.delete('SW_APM_ENABLED')
end

# For mkmf test case
def capture_stdout_with_pipe
  original_stdout = $stdout
  read_io, write_io = IO.pipe

  # Redirect stderr to write_io (the writing end of the pipe)
  $stdout = write_io
  begin
    yield # Run the code block that generates stderr output
  ensure
    $stdout = original_stdout # Restore the original stderr
    write_io.close # Close the writing end of the pipe to stop sending data
  end

  captured_output = read_io.read
  read_io.close
  captured_output
end

def stub_for_mkmf_test
  IO.stub(:copy_stream, nil) do
    URI.stub(:parse, URI.parse('https://github.com')) do
      URI::HTTPS.stub(:open, nil) do
        File.stub(:symlink, nil) do
          MakeMakefile.stub(:have_library, true) do
            MakeMakefile.stub(:create_makefile, true) do
              File.stub(:read, '1.2.3') do
                capture_stdout_with_pipe do
                  load 'ext/oboe_metal/extconf.rb'
                end
              end
            end
          end
        end
      end
    end
  end
end

# For dbo patching test
module Mysql2
  class Client
    attr_reader :query_options

    def initialize(_opts = {})
      @query_options = {}
    end

    def query(sql, _options = {})
      sql
    end
  end
end

module PG
  class Connection
    attr_reader :db, :user, :host, :conninfo_hash

    def initialize
      @conninfo_hash = {}
    end

    EXEC_ISH_METHODS = %i[
      exec
      query
      sync_exec
      async_exec
      exec_params
      async_exec_params
      sync_exec_params
    ].freeze

    EXEC_ISH_METHODS.each do |method|
      define_method method do |*args|
        args[0]
      end
    end
  end
  VERSION = '999.0.0'
end

module DisableAddView
  def init_response_time_metrics
    instrument = @meters['sw.apm.request.metrics'].create_histogram('trace.service.response_time', unit: 'ms', description: 'Duration of each entry span for the service, typically meaning the time taken to process an inbound request.')
    { response_time: instrument }
  end
end
