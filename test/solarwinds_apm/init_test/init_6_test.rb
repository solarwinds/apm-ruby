# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_6' do
  it 'SW_APM_SERVICE_KEY_is_invalid_empty_key' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = ''

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_SERVICE_KEY not configured.'
  end
end
