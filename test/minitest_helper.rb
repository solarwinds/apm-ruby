# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest'
require 'minitest/focus'
require 'minitest/debugger' if ENV['DEBUG']
require 'minitest/hooks/default'  # adds after(:all)
require 'opentelemetry/sdk'
require 'opentelemetry-common'
require 'opentelemetry-api'
require 'opentelemetry-propagator-b3'
require 'opentelemetry/exporter/otlp/version'
require 'opentelemetry-exporter-otlp'
require 'bson'

require './lib/solarwinds_apm/logger'

# write to a file as well as STDOUT (comes in handy with docker runs)
# This approach preserves the coloring of pass fail, which the cli
# `./run_tests.sh 2>&1 | tee -a test/docker_test.log` does not
if ENV['TEST_RUNS_TO_FILE']
  FileUtils.mkdir_p('log') # create if it doesn't exist
  if ENV['TEST_RUNS_FILE_NAME']
    $out_file = File.new(ENV['TEST_RUNS_FILE_NAME'], 'a')
  else
    $out_file = File.new("log/test_direct_runs_#{Time.now.strftime('%Y%m%d_%H_%M')}.log", 'a')
  end
  $out_file.sync = true
  $stdout.sync = true

  def $stdout.write(string)
    $out_file.write(string)
    super
  end
end

# Print out a headline in with the settings used in the test run
puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']} #{ENV['TEST_PREPARED_STATEMENT']} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

ENV['RACK_ENV'] = 'test'
MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new

# Bundler.require(:default, :test) # this load the solarwinds_apm library
SolarWindsAPM.logger.level = 1

# Extend Minitest with a refute_raises method
# There are debates whether or not such a method is needed,
# because the test would fail anyways when an exception is raised
#
# The reason to have and use it is for the statistics. The count of
# assertions, failures, and errors is less informative without refute_raises
module MiniTest
  module Assertions
    def refute_raises *exp
      begin
        yield
      rescue MiniTest::Skip => e
        return e if exp.include? MiniTest::Skip

        raise e
      rescue StandardError => e
        flunk "unexpected exception raised: #{e.message}"
      end

    end
  end
end

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
  module Context
    def self.toString
      '00-00000000000000000000000000000000-0000000000000000-00'
    end
    def self.clear; end
    def self.getDecisions(*args)
      do_metrics = 1
      do_sample = 0
      rate = 1_000_000
      status_msg = "auth-failed"
      auth_msg = "bad-signature"   
      source = 6
      bucket_rate = 0.0
      status = -5
      bucket_cap = 0
      ype = 0
      auth = 0
      return do_metrics, do_sample, rate, source, bucket_rate, bucket_cap, ype, auth, status_msg, auth_msg, status
    end

    def self.createEvent(args)
      self
    end
    def self.addInfo(k,v)
    end
  end
end

module SolarWindsAPM
  class Metadata
    def self.makeRandom
      Metadata.new
    end

    def self.fromString(str)
      '00-00000000000000000000000000000000-0000000000000000-00'
    end

    def isValid
      false
    end
  end
end

module SolarWindsAPM
  class Reporter
    class << self
      def send_report(evt, with_system_timestamp: true);
        true
      end
      def send_status(evt, context=nil, with_system_timestamp: true);
        true
      end
    end
  end
  def self.loaded
    true
  end
end

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  return unless SolarWindsAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'
  
  sleep 0.5
  File.truncate(SolarWindsAPM::OboeInitOptions.instance.host, 0)
end

##
# obtain_all_traces
#
# Retrieves all traces written to the trace file
#
def obtain_all_traces
  return [] unless SolarWindsAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'

  sleep 0.5
  io = File.open(SolarWindsAPM::OboeInitOptions.instance.host, 'r')
  contents = io.readlines(nil)
  io.close

  return contents if contents.empty?

  traces = []

  if Gem.loaded_specs['bson'] && Gem.loaded_specs['bson'].version.to_s < '4.0'
    s = StringIO.new(contents[0])

    until s.eof?
      traces << if ::BSON.respond_to? :read_bson_document
                  BSON.read_bson_document(s)
                else
                  BSON::Document.from_bson(s)
                end
    end
  else
    bbb = ::BSON::ByteBuffer.new(contents[0])
    traces << Hash.from_bson(bbb) until bbb.length == 0
  end

  traces
end

##
# create_context
# 
# create sample otel context 
#
def create_context(trace_id:,
                   span_id:,
                   trace_flags: ::OpenTelemetry::Trace::TraceFlags::DEFAULT)
  context = ::OpenTelemetry::Trace.context_with_span(
    ::OpenTelemetry::Trace.non_recording_span(
      ::OpenTelemetry::Trace::SpanContext.new(
        trace_id: Array(trace_id).pack('H*'),
        span_id: Array(span_id).pack('H*'),
        trace_flags: trace_flags)))
  conext_key = ::OpenTelemetry::Context.create_key('b3-debug-key')
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
  ENV.delete('SOLARWINDS_APM_ENABLED')
end
