# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require 'opentelemetry-metrics-sdk'

describe 'otlp processor test' do
  before do
    txn_manager = SolarWindsAPM::TxnNameManager.new
    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(txn_manager)
  end

  after do
    @processor.instance_variable_get(:@meters)['sw.apm.request.metrics'].instance_variable_set(:@instrument_registry, {})
  end

  it 'initializes_meters_and_metrics' do
    request_metrics           = @processor.instance_variable_get(:@meters)['sw.apm.request.metrics']
    sampling_metrics          = @processor.instance_variable_get(:@meters)['sw.apm.sampling.metrics']
    request_metrics_registry  = request_metrics.instance_variable_get(:@instrument_registry)
    sampling_metrics.instance_variable_get(:@instrument_registry)

    _(@processor.instance_variable_get(:@meters).size).must_equal 1
    _(@processor.instance_variable_get(:@metrics).size).must_equal 1

    refute_nil(request_metrics_registry['trace.service.response_time'])
  end

  it 'does_not_have_transaction_manager' do
    # currently otlp processor is only used in lambda which does not support transaction naming via SDK
    # this assumption may change when we introduce otlp export for non-lambda environments
    assert(@processor.txn_manager)
  end

  # TODO: tests for on_start and on_end behaviour
end
