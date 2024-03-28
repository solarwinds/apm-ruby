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

    _(SolarWindsAPM::Reporter.respond_to?(:start)).must_equal true
    _(SolarWindsAPM::Reporter.respond_to?(:send_status)).must_equal true
    _(SolarWindsAPM::Reporter.respond_to?(:send_report)).must_equal true
    _(SolarWindsAPM::Metadata.respond_to?(:makeRandom)).must_equal true
    _(SolarWindsAPM::Span.respond_to?(:createHttpSpan)).must_equal true
    _(SolarWindsAPM::Span.respond_to?(:createSpan)).must_equal true
    _(SolarWindsAPM::Context.toString).must_equal '99-00000000000000000000000000000000-0000000000000000-00'

    FileUtils.rm("#{Dir.pwd}/lib/libsolarwinds_apm.so")
  end
end
