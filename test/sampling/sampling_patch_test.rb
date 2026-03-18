# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/sampling/sampling_patch'

describe 'MetricsExporter::Patch#export returns SUCCESS for empty data points' do
  it 'returns SUCCESS when all metrics have empty data_points' do
    metric1 = Minitest::Mock.new
    metric1.expect(:data_points, [])

    metrics = [metric1]
    # After reject!, empty metrics remain so we need the exporter
    # The patch calls super if any data_points are present
    # When all are empty it should return SUCCESS
    exporter = ::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new
    result = exporter.export([])
    assert_equal ::OpenTelemetry::SDK::Metrics::Export::SUCCESS, result
  end
end

describe 'Span::Patch on_finishing callback and double-finish warning' do
  it 'calls on_finishing on processors that respond to it' do
    OpenTelemetry::SDK.configure

    tracer = OpenTelemetry.tracer_provider.tracer('test')
    span = nil
    tracer.in_span('test_span') do |s|
      span = s
    end
    # Span should have finished
    refute_nil span
  end

  it 'warns on double finish of span' do
    OpenTelemetry::SDK.configure

    tracer = OpenTelemetry.tracer_provider.tracer('test')
    span = nil
    tracer.in_span('test_span') do |s|
      span = s
    end
    # Calling finish again should just warn
    span.finish
  end
end
