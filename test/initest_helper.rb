# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'minitest'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/reporters'
require './lib/solarwinds_apm/logger'

ENV['SW_APM_SERVICE_KEY'] = 'this-is-a-dummy-api-token-for-testing-111111111111111111111111111111111:test-service'

# write to a file as well as STDOUT (comes in handy with docker runs)
# This approach preserves the coloring of pass fail, which the cli
# `./run_tests.sh 2>&1 | tee -a test/docker_test.log` does not
if ENV['TEST_RUNS_TO_FILE']
  FileUtils.mkdir_p('log') # create if it doesn't exist
  $out_file = if ENV['TEST_RUNS_FILE_NAME']
                File.new(ENV['TEST_RUNS_FILE_NAME'], 'a')
              else
                File.new("log/test_direct_runs_#{Time.now.strftime('%Y%m%d_%H_%M')}.log", 'a')
              end
  $out_file.sync = true
  $stdout.sync = true

  def $stdout.write(string)
    $out_file.write(string)
    super
  end
end

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$LOAD_PATH.unshift("#{Dir.pwd}/lib/")

def noop_shared_test
  _(defined?(SolarWindsAPM::API)).must_equal 'constant'
  _(SolarWindsAPM::API.solarwinds_ready?(300)).must_equal false
  assert_nil SolarWindsAPM::API.in_span('params')
  _(SolarWindsAPM::API.set_transaction_name).must_equal true
  _(SolarWindsAPM::API.current_trace_info.hash_for_log.to_s).must_equal '{}'
  _(SolarWindsAPM::API.current_trace_info.for_log).must_equal ''
  _(SolarWindsAPM::API.current_trace_info.tracestring).must_equal '00-00000000000000000000000000000000-0000000000000000-00'
  _(SolarWindsAPM::API.current_trace_info.trace_flags).must_equal '00'
  _(SolarWindsAPM::API.current_trace_info.span_id).must_equal '0000000000000000'
  _(SolarWindsAPM::API.current_trace_info.trace_id).must_equal '00000000000000000000000000000000'
  _(SolarWindsAPM::API.current_trace_info.do_log).must_equal :never

  in_span_result = SolarWindsAPM::API.in_span('params') do |_span|
    value = 1 + 1
    value
  end

  _(in_span_result).must_equal 2
end
