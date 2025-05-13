# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/sampling/sampling_patch'
require 'opentelemetry-metrics-sdk'

describe 'otlp processor sampled test' do
  puts "\n\033[1m=== OTLP PROCESSOR TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  before do
    txn_manager = SolarWindsAPM::TxnNameManager.new
    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(txn_manager)
  end

  it 'initializes_meters_and_metrics' do
    request_metrics           = @processor.instance_variable_get(:@meters)['sw.apm.request.metrics']
    request_metrics_registry  = request_metrics.instance_variable_get(:@instrument_registry)

    _(@processor.instance_variable_get(:@meters).size).must_equal 1
    _(@processor.instance_variable_get(:@metrics).size).must_equal 1

    refute_nil(request_metrics_registry['trace.service.response_time'])
  end

  it 'ensure_both_span_and_metrics_have_transaction_name' do
    OpenTelemetry::SDK.configure
    metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    trace_exporter  = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(trace_exporter)

    provider = OpenTelemetry.tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new.tap do |provider|
      provider.add_span_processor(span_processor)
      provider.add_span_processor(@processor)
    end
    OpenTelemetry.meter_provider.add_metric_reader(metric_exporter)

    tracer = provider.tracer(__FILE__, OpenTelemetry::SDK::VERSION)
    parent_context = OpenTelemetry::Context.empty

    OpenTelemetry::Context.with_current(parent_context) do
      tracer.in_span('just_a_simple_name') do
        # no-op
      end

      metric_exporter.pull
      metrics = metric_exporter.metric_snapshots
      _(metrics[0].data_points[0].attributes['sw.transaction']).must_equal 'just_a_simple_name'
      _(trace_exporter.finished_spans[0].attributes['sw.transaction']).must_equal 'just_a_simple_name'
    end
  end
end
