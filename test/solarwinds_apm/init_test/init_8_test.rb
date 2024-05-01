# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'
require 'fileutils'

describe 'solarwinds_apm_init_8' do
  it 'when_there_is_problem_solarwinds_apm_load_false' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    FileUtils.cp("#{Dir.pwd}/test/clib/solarwinds_apm.so", "#{Dir.pwd}/lib/libsolarwinds_apm.so")

    ENV['SW_APM_REPORTER'] = 'file'

    require './lib/solarwinds_apm'

    assert_includes log_output.string, 'SolarWindsAPM not loaded. SolarWinds APM disabled'
    assert_includes log_output.string, 'Please check previous log messages.'

    _(SolarWindsAPM.loaded).must_equal false

    FileUtils.rm("#{Dir.pwd}/lib/libsolarwinds_apm.so")

    noop_shared_test
  end
end
