# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWinds Transaction Setting Test' do

  it 'test non transaction_settings' do
    SolarWindsOTelAPM::Config[:transaction_settings] = {
      url: [],
      spankind: []
    }
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: 'google.ca', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode(kind:'url')).must_equal 1
    _(trans_settings.calculate_trace_mode(kind:'spankind')).must_equal 1
  end

  it 'test url transaction_settings with enable' do
    SolarWindsOTelAPM::Config[:transaction_settings] = {
      url: [
        {
          regexp: '^.*\/google\/.*$',
          opts: Regexp::IGNORECASE,
          tracing: :disabled
        }
      ],
      spankind: []
    }

    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode(kind:'url')).must_equal 0
    _(trans_settings.calculate_trace_mode(kind:'spankind')).must_equal 1
  end

  it 'test url transaction_settings with enable' do
    SolarWindsOTelAPM::Config[:transaction_settings] = {
      url: [],
      spankind: [
        {
          regexp: '.*HTTP GET:connect.*',
          opts: Regexp::IGNORECASE,
          tracing: :disabled
        }
      ]
    }

    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode(kind:'url')).must_equal 1
    _(trans_settings.calculate_trace_mode(kind:'spankind')).must_equal 0
  end


end
