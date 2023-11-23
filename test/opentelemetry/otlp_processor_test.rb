# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'otlp processor test' do

  before do
    @exporter        = ::OpenTelemetry::Exporter::OTLP::Exporter.new
    @metric_exporter = ::OpenTelemetry::Exporter::OTLP::MetricsExporter.new
    @txn_manager = SolarWindsAPM::TxnNameManager.new
    
    @meters = {'sw.apm.sampling.metrics' => ::OpenTelemetry.meter_provider.meter('sw.apm.sampling.metrics'),
              'sw.apm.request.metrics'  => ::OpenTelemetry.meter_provider.meter('sw.apm.request.metrics')
    }

    @processor = SolarWindsAPM::OpenTelemetry::OTLPProcessor.new(@meters, @txn_manager, @exporter)
  end

  after do
    @processor.instance_variable_get(:@meters)['sw.apm.request.metrics'].instance_variable_set(:@instrument_registry, {})
    @processor.instance_variable_get(:@meters)['sw.apm.sampling.metrics'].instance_variable_set(:@instrument_registry, {})
  end

  it 'processor_meters_should_be_nil_at_beginning' do

    _(@processor.instance_variable_get(:@metrics).size).must_equal 0
    _(@processor.instance_variable_get(:@description).size).must_equal 0
  end

  it 'test_on_start_verfy_component_initialized_correctly' do
    @processor.on_start(create_span, ::OpenTelemetry::Context.current)

    request_metrics           = @processor.instance_variable_get(:@meters)['sw.apm.request.metrics']
    sampling_metrics          = @processor.instance_variable_get(:@meters)['sw.apm.sampling.metrics']
    request_metrics_registry  = request_metrics.instance_variable_get(:@instrument_registry)
    sampling_metrics_registry = sampling_metrics.instance_variable_get(:@instrument_registry)

    _(@processor.txn_manager.get_root_context_h('77cb6ccc522d3106114dd6ecbb70036a')).must_equal "31e175128efc4018-00"
    _(@processor.instance_variable_get(:@metrics).size).must_equal 11
    _(@processor.instance_variable_get(:@description).size).must_equal 0

    refute_nil(request_metrics_registry['trace.service.response_time'])
    refute_nil(request_metrics_registry['trace.service.requests'])
    refute_nil(request_metrics_registry['trace.service.errors'])
    refute_nil(sampling_metrics_registry['trace.service.tracecount'])
    refute_nil(sampling_metrics_registry['trace.service.samplecount'])
    refute_nil(sampling_metrics_registry['trace.service.request_count'])
    refute_nil(sampling_metrics_registry['trace.service.tokenbucket_exhaustion_count'])
    refute_nil(sampling_metrics_registry['trace.service.through_trace_count'])
    refute_nil(sampling_metrics_registry['trace.service.triggered_trace_count'])
    refute_nil(sampling_metrics_registry['trace.service.sample_rate'])
    refute_nil(sampling_metrics_registry['trace.service.sample_source'])
  end



end
