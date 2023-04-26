# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'simplecov' if ENV['SIMPLECOV_COVERAGE']
require 'simplecov-console' if ENV['SIMPLECOV_COVERAGE']

if ENV['SIMPLECOV_COVERAGE']
  SimpleCov.start do
    # SimpleCov.formatter = SimpleCov.formatter = SimpleCov::Formatter::Console
    merge_timeout 3600
    command_name "#{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']}"
    # SimpleCov.use_merging true
    add_filter '/test/'
    add_filter '../test/'
    use_merging true
  end
end

require 'rubygems'
require 'bundler/setup'
require 'fileutils'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest'
require 'minitest/focus'
require 'minitest/debugger' if ENV['DEBUG']
require 'minitest/hooks/default'  # adds after(:all)
require 'opentelemetry'
require 'opentelemetry/sdk'
require 'opentelemetry-sdk'
require 'opentelemetry-common'
require 'opentelemetry-api'
require 'opentelemetry-propagator-b3'
require 'opentelemetry-exporter-otlp'
require 'bson'

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

module Exporter
  class Dummy
    def flush(); end
  end
end

# Print out a headline in with the settings used in the test run
puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']} #{ENV['TEST_PREPARED_STATEMENT']} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

ENV['RACK_ENV'] = 'test'
MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new

Bundler.require(:default, :test)
SolarWindsOTelAPM.logger.level = 1

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  return unless SolarWindsOTelAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'
    
  while SolarWindsOTelAPM::Reporter.obtain_all_traces.size != 0
    SolarWindsOTelAPM::Reporter.clear_all_traces
    sleep 0.2
  end
end

##
# obtain_all_traces
#
# Retrieves all traces written to the trace file
#
def obtain_all_traces
  return [] unless SolarWindsOTelAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'

  sleep 0.5
  SolarWindsOTelAPM::Reporter.obtain_all_traces
end

##
# read the ActiveRecord logfile and match it with regex
# use case: test if trace-id has been injected in query
#
# `clear_query_log` before next test
def query_logged?(regex)
  File.open(ENV['QUERY_LOG_FILE']).read =~ regex
end

def print_query_log
  puts File.open(ENV['QUERY_LOG_FILE']).read
end

##
# clear the ActiveRecord logfile, but don't remove it
# create if it doesn't exist
#
def clear_query_log
  ENV['QUERY_LOG_FILE'] ||= '/tmp/query_log.txt'
  if File.exist?(ENV['QUERY_LOG_FILE'])
    File.truncate(ENV['QUERY_LOG_FILE'], 0)
  else
    FileUtils.touch(ENV['QUERY_LOG_FILE'])
  end
end

##
# validate_outer_layers
#
# Validates that the KVs in kvs are present
# in event
#
def validate_outer_layers(traces, layer)
  assert_equal traces.first['Layer'], layer
  assert_equal traces.first['Label'], 'entry'
  assert_equal traces.last['Layer'], layer
  assert_equal traces.last['Label'], 'exit'
end

##
# validate_event_keys
#
# Validates that the KVs in kvs are present
# in event
#
def validate_event_keys(event, kvs)
  kvs.each do |k, v|
    assert event.has_key?(k), "#{k} is missing"
    assert_equal event[k], v, "#{k} != #{v} (#{event[k]})"
  end
end

##
# edge?
#
# Searches the array of <tt>traces</tt> for
# <tt>edge</tt>
#
def edge?(edge, traces)
  traces.each do |t|
    return true if SolarWindsOTelAPM::TraceString.span_id(t['sw.trace_context']) == edge
  end
  SolarWindsOTelAPM.logger.debug "[solarwinds_apm/test] edge #{edge} not found in traces."
  false
end

def assert_entry_exit(traces, num=nil, check_trace_id: true)
  if check_trace_id
    trace_id = SolarWindsOTelAPM::TraceString.trace_id(traces[0]['sw.trace_context'])
    refute traces.find { |tr| SolarWindsOTelAPM::TraceString.trace_id(tr['sw.trace_context']) != trace_id }, 'trace ids not matching'
  end
  num_entries = traces.select { |tr| tr ['Label'] == 'entry' }.size
  num_exits = traces.select { |tr| tr ['Label'] == 'exit' }.size
  if num && num > 0
    _(num_entries).must_equal num, 'incorrect number of entry spans'
    _(num_exits).must_equal num, 'incorrect number of exit spans'
  else
    _(num_exits).must_equal num_entries, 'number of exit spans is not the same as entry spans'
  end
end

##
# valid_edges?
#
# Runs through the array of <tt>traces</tt> to validate
# that all edges connect.
#
# Not that this won't work for external cross-app tracing
# since we won't have those remote traces to validate
# against.
#
# The param connected can be set to false if there are disconnected traces
#
def valid_edges?(traces, connected: true)
  return true unless traces.is_a?(Array) && traces.count > 1 # so that in case the traces are sent to the collector, tests will fail but not barf
  
  parent_span_id = 'sw.parent_span_id'.freeze
  traces[1..].reverse.each do |t|
    next unless t.has_key?(parent_span_id)

    next if edge?(t[parent_span_id], traces)
  
    puts "edge missing for #{t[parent_span_id]}"
    print_traces(traces)
    return false
  end

  if connected
    return true if traces.map { |tr| tr[parent_span_id] }.uniq.size == traces.size
    
    puts "number of unique sw.parent_span_ids: #{traces.map { |tr| tr[parent_span_id] }.uniq.size}"
    puts "number of traces: #{traces.size}"
    print_traces(traces)
    return false
  end
  true
end

##
# same_trace_id?
#
# do the events all have the same trace_id?
# 
def same_trace_id?(traces)
  traces.map do |t|
    SolarWindsOTelAPM::TraceString.trace_id(t["sw.trace_context"])
  end.uniq.count == 1
end

##
# layer_has_key
#
# Checks an array of trace events if a specific layer (regardless of event type)
# has he specified key
#
def layer_has_key(traces, layer, key)
  return false if traces.empty?

  has_key = false
  traces.each do |t|
    if t["Layer"] == layer && t.has_key?(key)
      has_key = true
      _(t[key].length > 0).must_equal true
    end
  end

  _(has_key).must_equal true
end

##
# layer_has_key
#
# Checks an array of trace events if a specific layer (regardless of event type)
# has he specified key
#
def layer_has_key_once(traces, layer, key)
  return false if traces.empty?

  has_keys = 0
  traces.each do |t|
    has_keys += 1 if t["Layer"] == layer && t.has_key?(key)
  end

  _(has_keys).must_equal 1, "Key #{key} missing in layer #{layer}"
end

##
# layer_doesnt_have_key
#
# Checks an array of trace events to assure that a specific layer
# (regardless of event type) doesn't have the specified key
#
def layer_doesnt_have_key(traces, layer, key)
  return false if traces.empty?

  has_key = false
  traces.each do |t|
    has_key = true if t["Layer"] == layer && t.has_key?(key)
  end

  _(has_key).must_equal false, "Key #{key} should not be in layer #{layer}"
end

##
# Checks if the transaction name corresponds to Controller.Action
# if there are multiple events with Controller and/or Action, then they all have to match
#
def assert_controller_action(test_action)
  traces = obtain_all_traces
  traces.select { |tr| tr['Controller'] || tr['Action'] }.map do |tr|
    assert_equal(test_action, [tr['Controller'], tr['Action']].join('.'))
  end
end

def not_sampled?(tracestring)
  !sampled?(tracestring)
end

def sampled?(tracestring)
  SolarWindsOTelAPM::TraceString.sampled?(tracestring)
end

#########################            ###            ###            ###            ###            ###
### DEBUGGING HELPERS ###
#########################

def pretty(traces)
  puts traces.pretty_inspect
end

def print_traces(traces, more_keys=[])
  return unless traces.is_a?(Array) # so that in case the traces are sent to the collector, tests will fail but not barf
  
  more_keys << 'sw.tracestate_parent_id'
  indent = ''
  puts "\n"
  traces.each do |trace|
    indent += '  ' if trace['Label'] == 'entry'

    puts "#{indent}Label:   #{trace['Label']}"
    puts "#{indent}Layer:   #{trace['Layer']}"
    puts "#{indent}sw.trace_context: #{trace['sw.trace_context']}"
    puts "#{indent}sw.parent_span_id: #{trace['sw.parent_span_id']}"

    more_keys.each { |key| puts "#{indent}#{key}:   #{trace[key]}" if trace[key] }

    indent = indent[0...-2] if trace['Label'] == 'exit'
  end
  puts "\n"
end

# a method to reduce the number of kvs
# mainly helpful for the msg when an assertion fails
def filter_traces(traces, more_keys=[])
  keys = more_keys.dup
  keys |= %w[Layer Label sw.trace_context sw.parent_span_id sw.tracestate_parent_id]

  traces.map {|tr| tr.select{|k, _v| keys.include?(k) }}
end

def print_edges(traces)
  traces.each do |trace|
    puts "EVENT: Edge: #{trace['Edge']} (#{trace['Label']}) \nnext Edge: #{trace['X-Trace'][42..-3]}\n"
  end
end

# this checks if `sw=...` is at the beginning of tracestate and returns the value
def sw_tracestate(tracestate)
  matches = /^[,\s]*sw=(?<sw_value>[a-f0-9]{16}-0[01])/.match(tracestate)
  matches && matches[:sw_value]
end

# this extracts the sw value anywhere within tracestate
def sw_value(tracestate)
  matches = /[,\s]*sw=(?<sw_value>[a-f0-9]{16}-0[01])/.match(tracestate)
  matches && matches[:sw_value]
end

def create_context(trace_id:,
                   span_id:,
                   trace_flags: OpenTelemetry::Trace::TraceFlags::DEFAULT)
  context = OpenTelemetry::Trace.context_with_span(
    OpenTelemetry::Trace.non_recording_span(
      OpenTelemetry::Trace::SpanContext.new(
        trace_id: Array(trace_id).pack('H*'),
        span_id: Array(span_id).pack('H*'),
        trace_flags: trace_flags)))
  conext_key = OpenTelemetry::Context.create_key('b3-debug-key')
  context.set_value(conext_key, true)
end

def clean_old_setting
  ENV.delete('OTEL_PROPAGATORS')
  ENV.delete('OTEL_TRACES_EXPORTER')
end

if (File.basename(ENV['BUNDLE_GEMFILE']) =~ /^frameworks/) == 0
  require "sinatra"
  ##
  # Sinatra and Padrino Related Helpers
  #
  # Taken from padrino-core gem
  # Sinatra::Base
  class Sinatra::Base
    # Allow assertions in request context
    include MiniTest::Assertions
  end

  # MiniTest::Spec
  class MiniTest::Spec
    include Rack::Test::Methods

    # Sets up a Sinatra::Base subclass defined with the block
    # given. Used in setup or individual spec methods to establish
    # the application.
    def mock_app(base=Padrino::Application, &block)
      @app = Sinatra.new(base, &block)
    end

    def app
      Rack::Lint.new(@app)
    end
  end
end
