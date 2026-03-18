# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require 'opentelemetry-metrics-sdk'
require './lib/solarwinds_apm/sampling'

describe 'Metrics::Counter initialization and key access' do
  it 'initializes counters' do
    counter = SolarWindsAPM::Metrics::Counter.new
    refute_nil counter[:request_count]
    refute_nil counter[:sample_count]
    refute_nil counter[:trace_count]
    refute_nil counter[:through_trace_count]
    refute_nil counter[:triggered_trace_count]
    refute_nil counter[:token_bucket_exhaustion_count]
  end

  it 'returns nil for unknown key' do
    counter = SolarWindsAPM::Metrics::Counter.new
    assert_nil counter[:nonexistent]
  end
end
