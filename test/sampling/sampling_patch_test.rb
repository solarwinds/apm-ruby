# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/sampling/sampling_patch'

describe 'MetricsExporter::Patch#export returns SUCCESS for empty data points' do
  it 'returns SUCCESS when all metrics have empty data_points' do
    metric_data = Minitest::Mock.new
    metric_data.expect(:data_points, [])

    exporter = OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new
    result = exporter.export([metric_data])
    assert_equal OpenTelemetry::SDK::Metrics::Export::SUCCESS, result
  end
end

describe 'Span::Patch on_finishing callback and double-finish warning' do
  before do
    # rubocop:disable Lint/EmptyBlock
    @custom_processor = Object.new
    @custom_processor.define_singleton_method(:on_start) { |_, _| }
    @custom_processor.define_singleton_method(:on_finish) { |_| }
    @custom_processor.define_singleton_method(:force_flush) { |**| }
    @custom_processor.define_singleton_method(:shutdown) { |**| }
    # rubocop:enable Lint/EmptyBlock
  end

  it 'avoids deadlock when processor calls span.set_attribute in on_finishing' do
    attribute_set = false
    @custom_processor.define_singleton_method(:on_finishing) do |span|
      span.set_attribute('hello', 'world')
      attribute_set = true
    end

    OpenTelemetry::SDK.configure { |c| c.add_span_processor(@custom_processor) }

    tracer = OpenTelemetry.tracer_provider.tracer('test')
    span = nil
    tracer.in_span('test_span') { |s| span = s }

    assert attribute_set, 'Expected on_finishing to set attribute without deadlock'
    assert_equal 'world', span.attributes['hello']
  end

  it 'raises ThreadError without patch when processor calls set_attribute in on_finishing' do
    thread_error_raised = false
    @custom_processor.define_singleton_method(:on_finishing) do |span|
      span.set_attribute('hello', 'world')
    rescue ThreadError
      thread_error_raised = true
    end

    OpenTelemetry::SDK.configure { |c| c.add_span_processor(@custom_processor) }

    span = OpenTelemetry.tracer_provider.tracer('test').start_span('test_span')

    # Retrieve the original (unpatched) finish via super_method on the prepended method,
    # then bind and call it on the real span to exercise the original SDK locking behaviour.
    original_finish = OpenTelemetry::SDK::Trace::Span.instance_method(:finish).super_method
    # verify that the original_finish is indeed from method from original span.rb
    assert_includes original_finish.to_s, 'lib/opentelemetry/sdk/trace/span.rb'

    original_finish.bind_call(span)
    assert thread_error_raised, 'Expected ThreadError from recursive mutex lock in original SDK finish'
  end

  it 'warns on double finish of span' do
    OpenTelemetry::SDK.configure

    tracer = OpenTelemetry.tracer_provider.tracer('test')
    span = nil
    tracer.in_span('test_span') do |s|
      span = s
    end
    assert_equal 'test_span', span.name

    warned = false
    OpenTelemetry.logger.stub(:warn, ->(_msg = nil) { warned = true }) do
      span.finish
    end
    assert warned, 'Expected a warning to be logged on double finish'
  end
end
