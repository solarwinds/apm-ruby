# frozen_string_literal: true

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
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET',
                                                            kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url_path transaction_settings with no disabled (disabled is default)' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$'
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET',
                                                            kind: :connect)
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

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET',
                                                            kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0
  end

  it 'test url_path transaction_settings with both regexp enable and disable' do
    SolarWindsAPM::Config[:transaction_settings] = [
      {
        regexp: '^.*\/google\/.*$',
        opts: Regexp::IGNORECASE,
        tracing: :enabled
      }
    ]
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET',
                                                            kind: :connect)
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
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/', name: 'HTTP GET',
                                                            kind: :connect)
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
    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/cool_image.png',
                                                            name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/images/image.js',
                                                            name: 'HTTP GET', kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 0

    trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: '/search/google/imagesjs/', name: 'HTTP GET',
                                                            kind: :connect)
    _(trans_settings.calculate_trace_mode).must_equal 1
  end
end

describe 'TransactionSettings#calculate_trace_mode with tracing modes and regexp filtering' do
  before do
    @original_tracing_mode = SolarWindsAPM::Config[:tracing_mode]
    @original_enabled_regexps = SolarWindsAPM::Config[:enabled_regexps]
    @original_disabled_regexps = SolarWindsAPM::Config[:disabled_regexps]
  end

  after do
    SolarWindsAPM::Config[:tracing_mode] = @original_tracing_mode
    SolarWindsAPM::Config[:enabled_regexps] = @original_enabled_regexps
    SolarWindsAPM::Config[:disabled_regexps] = @original_disabled_regexps
  end

  describe 'calculate_trace_mode' do
    it 'returns enabled when tracing_mode is enabled and no filters match' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:enabled_regexps] = nil
      SolarWindsAPM::Config[:disabled_regexps] = nil

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '/api/test', name: 'test', kind: :server)
      assert_equal 1, ts.calculate_trace_mode
    end

    it 'returns disabled when tracing_mode is not enabled' do
      SolarWindsAPM::Config[:tracing_mode] = :disabled
      ts = SolarWindsAPM::TransactionSettings.new(url_path: '/test', name: 'test', kind: :server)
      assert_equal 0, ts.calculate_trace_mode
    end

    it 'returns disabled when url matches disabled regexp' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:disabled_regexps] = [/\/health/]
      SolarWindsAPM::Config[:enabled_regexps] = nil

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '/health', name: 'test', kind: :server)
      assert_equal 0, ts.calculate_trace_mode
    end

    it 'returns enabled when url matches enabled regexp' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:enabled_regexps] = [/\/api/]
      SolarWindsAPM::Config[:disabled_regexps] = nil

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '/api/test', name: 'test', kind: :server)
      assert_equal 1, ts.calculate_trace_mode
    end

    it 'returns disabled when span layer matches disabled regexp' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:disabled_regexps] = [/server:background_job/]
      SolarWindsAPM::Config[:enabled_regexps] = nil

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '', name: 'background_job', kind: 'server')
      assert_equal 0, ts.calculate_trace_mode
    end

    it 'returns enabled when span layer matches enabled regexp' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:enabled_regexps] = [/server:api_call/]
      SolarWindsAPM::Config[:disabled_regexps] = nil

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '', name: 'api_call', kind: 'server')
      assert_equal 1, ts.calculate_trace_mode
    end

    it 'disabled takes priority over enabled for url' do
      SolarWindsAPM::Config[:tracing_mode] = :enabled
      SolarWindsAPM::Config[:disabled_regexps] = [/\/api/]
      SolarWindsAPM::Config[:enabled_regexps] = [/\/api/]

      ts = SolarWindsAPM::TransactionSettings.new(url_path: '/api/test', name: 'test', kind: :server)
      assert_equal 0, ts.calculate_trace_mode
    end
  end
end
