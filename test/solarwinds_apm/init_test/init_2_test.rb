# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_2' do
  it 'SW_APM_SERVICE_KEY_is_invalid' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = ':abcd'

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_SERVICE_KEY problem. API Token in wrong format'

    noop_shared_test
  end
end
