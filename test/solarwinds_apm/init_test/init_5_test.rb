# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_5' do
  it 'warns instead of raising when loading the library fails' do
    require 'solarwinds_apm/version'
    require 'solarwinds_apm/constants'
    require 'solarwinds_apm/config'
    require 'solarwinds_apm/otel_config'

    SolarWindsAPM::OTelConfig.define_singleton_method(:initialize) { raise StandardError, 'init failed' }

    _, err = capture_io { require './lib/solarwinds_apm' }

    assert_includes err, '[solarwinds_apm/error] Problem loading'
    assert_includes err, 'init failed'
  end
end
