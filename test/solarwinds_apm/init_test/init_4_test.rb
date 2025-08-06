# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_4' do
  it 'everything_default' do
    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'Current solarwinds_apm version:'
  end
end
