# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/transaction_settings'

describe 'SolarWinds Transaction Setting Test' do

  it 'test non transaction_settings' do
    SolarWindsAPM::Config[:transaction_settings] = []
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: 'google.ca', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 1
  end

  it 'test url_path transaction_settings with disabled' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url_path transaction_settings with no disabled (disabled is default)' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$'
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test spankind transaction_settings with enable' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '.*connect:HTTP GET.*',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url_path transaction_settings with both regexp enable and extensions disable' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :enabled
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 1
  end

  it 'test url_path transaction_settings with both regexp enable and span_layer disable' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :enabled
      },
      {
        regexp: '.*connect:HTTP GET.*',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 1
  end

  it 'test url_path with asset like extensions' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '\.(css|js|png)$',
        opts: Regexp::IGNORECASE,
        tracing: :disabled
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/cool_image.png', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/image.js', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/imagesjs/', name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 1
  end
end
