# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_3' do
  it 'SW_APM_AUTO_CONFIGURE_set_to_false' do
    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_AUTO_CONFIGURE'] = 'false'

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_AUTO_CONFIGURE set to false.'

    noop_shared_test
  end
end
