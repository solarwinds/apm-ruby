# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWinds Transaction Setting Test' do

  it 'test non transaction_settings' do
    SolarWindsOTelAPM::Config[:transaction_settings] = []
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: 'google.ca', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 1
  end

  it 'test url transaction_settings with disabled' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url transaction_settings with extension disabled' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        extensions: %w[search],
        tracing: :disabled
      }
    ]

    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search?q=ruby', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url transaction_settings with no disabled (disabled is default)' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$'
      }
    ]
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test spankind transaction_settings with enable' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '.*HTTP GET:connect.*',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]

    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url transaction_settings with both regexp and extensions' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      },
      {
        extensions: %w[google],
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url transaction_settings with both regexp enable and extensions disable' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :enabled
      },
      {
        extensions: %w[google],
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 1
  end

  it 'test url transaction_settings with both regexp enable and span_layer disable' do
    SolarWindsOTelAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :enabled
      },
      {
        regexp: '.*HTTP GET:connect.*',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsOTelAPM::TransactionSettings.new(url: '/search/google/images/', name: 'HTTP GET', kind: 'connect')
    _(trans_settings.calculate_trace_mode).must_equal 1
  end
end
