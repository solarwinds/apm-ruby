# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_1' do
  it 'logs disabled message and enters noop mode when SW_APM_ENABLED is false' do
    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_ENABLED'] = 'false'

    require './lib/solarwinds_apm'
    assert_includes log_output.string,
                    'SW_APM_ENABLED environment variable detected and was set to false. SolarWindsAPM disabled'

    noop_shared_test
  end
end
