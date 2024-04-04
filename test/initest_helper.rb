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

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$LOAD_PATH.unshift("#{Dir.pwd}/lib/")
