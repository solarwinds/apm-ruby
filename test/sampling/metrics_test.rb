# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require 'opentelemetry-metrics-sdk'
require './lib/solarwinds_apm/sampling'

describe 'Metrics::Counter initialization and key access' do
  before do
    @original_meter_provider = OpenTelemetry.meter_provider
    OpenTelemetry.meter_provider = OpenTelemetry::SDK::Metrics::MeterProvider.new
  end

  after do
    OpenTelemetry.meter_provider = @original_meter_provider
  end

  it 'initializes counters' do
    counter = SolarWindsAPM::Metrics::Counter.new
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:request_count]
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:sample_count]
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:trace_count]
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:through_trace_count]
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:triggered_trace_count]
    assert_instance_of OpenTelemetry::SDK::Metrics::Instrument::Counter, counter[:token_bucket_exhaustion_count]
  end

  it 'returns nil for unknown key' do
    counter = SolarWindsAPM::Metrics::Counter.new
    assert_nil counter[:nonexistent]
  end
end
