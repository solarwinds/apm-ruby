# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_2' do
  it 'logs token format error and enters noop mode when service key is invalid' do
    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_SERVICE_KEY'] = ':abcd'

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_SERVICE_KEY problem. API Token in wrong format. Masked token'

    noop_shared_test
  end
end
