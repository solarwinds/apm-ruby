# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
    clean_old_setting
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config_map, {})
    sleep 1
  end

  # Exporter Testing
  it 'test_exporter_with_default' do

    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors).count).must_equal 1
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].instance_variable_get(:@exporter).class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_exporter_with_default_otlp_exporter' do

    ENV['OTEL_TRACES_EXPORTER'] = 'otlp'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors).count).must_equal 2
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].class).must_equal ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].instance_variable_get(:@exporter).class).must_equal OpenTelemetry::Exporter::OTLP::Exporter
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[1].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[1].instance_variable_get(:@exporter).class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_exporter_with_bad_exporter' do

    ENV['OTEL_TRACES_EXPORTER'] = 'abcd'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors).count).must_equal 1
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
    _(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)[0].instance_variable_get(:@exporter).class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end
end

