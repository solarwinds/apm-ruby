# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_1' do
  it 'SW_APM_ENABLED_set_to_disabled' do
    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_ENABLED'] = 'false'

    require './lib/solarwinds_apm'
    assert_includes log_output.string,
                    'SW_APM_ENABLED environment variable detected and was set to false. SolarWindsAPM disabled'

    noop_shared_test
  end
end
