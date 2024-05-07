# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_5' do
  it 'SW_APM_SERVICE_KEY_is_invalid_missing_service_name_and_semicolon' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = 'this-is-a-dummy-api-token-for-testing-111111111111111111111111111111111'

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_SERVICE_KEY format problem. Service Name is missing.'

    noop_shared_test
  end
end
