# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require 'opentelemetry-metrics-sdk'

describe 'otlp processor test' do
  before do
    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new
  end

  after do
    @processor.instance_variable_get(:@meters)['sw.apm.request.metrics'].instance_variable_set(:@instrument_registry, {})
    @processor.instance_variable_get(:@meters)['sw.apm.sampling.metrics'].instance_variable_set(:@instrument_registry, {})
  end

  it 'initializes_meters_and_metrics' do
    request_metrics           = @processor.instance_variable_get(:@meters)['sw.apm.request.metrics']
    sampling_metrics          = @processor.instance_variable_get(:@meters)['sw.apm.sampling.metrics']
    request_metrics_registry  = request_metrics.instance_variable_get(:@instrument_registry)
    sampling_metrics_registry = sampling_metrics.instance_variable_get(:@instrument_registry)

    _(@processor.instance_variable_get(:@meters).size).must_equal 2
    _(@processor.instance_variable_get(:@metrics).size).must_equal 7

    refute_nil(request_metrics_registry['trace.service.response_time'])
    refute_nil(sampling_metrics_registry['trace.service.tracecount'])
    refute_nil(sampling_metrics_registry['trace.service.samplecount'])
    refute_nil(sampling_metrics_registry['trace.service.request_count'])
    refute_nil(sampling_metrics_registry['trace.service.tokenbucket_exhaustion_count'])
    refute_nil(sampling_metrics_registry['trace.service.through_trace_count'])
    refute_nil(sampling_metrics_registry['trace.service.triggered_trace_count'])
  end

  it 'does_not_have_transaction_manager' do
    # currently otlp processor is only used in lambda which does not support transaction naming via SDK
    # this assumption may change when we introduce otlp export for non-lambda environments
    assert_nil(@processor.txn_manager)
  end

  # TODO: tests for on_start and on_end behaviour
end
