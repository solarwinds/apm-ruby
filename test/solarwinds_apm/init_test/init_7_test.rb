# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_7' do
  it 'when_there_is_problem_loading_solarwinds_apm_so' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_REPORTER'] = 'file'

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'Error occurs while loading solarwinds_apm. SolarWinds APM disabled.'
    assert_includes log_output.string, 'Error: cannot load such file'
    assert_includes log_output.string, 'See: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'

    assert_nil(defined?(SolarWindsAPM.loaded))

    noop_shared_test
  end
end
