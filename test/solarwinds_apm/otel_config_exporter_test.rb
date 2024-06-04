# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'Loading Opentelemetry Test' do
  before do
    clean_old_setting
    SolarWindsAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config_map, {})
  end

  # Exporter Testing
  it 'test_exporter_with_default' do
    SolarWindsAPM::OTelConfig.initialize
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true

    span_processors = OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    _(span_processors.count).must_equal 2
    _(span_processors[0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsProcessor
    assert_nil(span_processors[0].instance_variable_get(:@exporter))
  end

  it 'test_exporter_with_default_otlp_exporter' do
    ENV['OTEL_TRACES_EXPORTER'] = 'otlp'
    SolarWindsAPM::OTelConfig.initialize
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    span_processors = OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    _(span_processors.count).must_equal 3
    _(span_processors[0].class).must_equal OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor
    _(span_processors[0].instance_variable_get(:@exporter).class).must_equal OpenTelemetry::Exporter::OTLP::Exporter
    _(span_processors[1].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsProcessor
    assert_nil(span_processors[1].instance_variable_get(:@exporter))
  end

  it 'test_exporter_with_bad_exporter' do
    ENV['OTEL_TRACES_EXPORTER'] = 'abcd'
    SolarWindsAPM::OTelConfig.initialize
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true

    span_processors = OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    _(span_processors.count).must_equal 2
    _(span_processors[0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsProcessor
    assert_nil(span_processors[0].instance_variable_get(:@exporter))
  end

  it 'test_exporter_with_zipkin_jaeger_exporter' do
    ENV['OTEL_TRACES_EXPORTER'] = 'otlp,console'
    SolarWindsAPM::OTelConfig.initialize
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true

    span_processors = OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    _(span_processors.count).must_equal 4
    _(span_processors[0].class).must_equal OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor
    _(span_processors[0].instance_variable_get(:@exporter).class).must_equal OpenTelemetry::Exporter::OTLP::Exporter
    _(span_processors[1].class).must_equal OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor
    _(span_processors[1].instance_variable_get(:@span_exporter).class).must_equal OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter
    _(span_processors[2].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsProcessor
    assert_nil(span_processors[2].instance_variable_get(:@exporter))
  end

  it 'test_exporter_with_empty_OTEL_TRACES_EXPORTER' do
    ENV['OTEL_TRACES_EXPORTER'] = ''
    SolarWindsAPM::OTelConfig.initialize
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true

    span_processors = OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    _(span_processors.count).must_equal 2
    _(span_processors[0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsProcessor
    assert_nil(span_processors[0].instance_variable_get(:@exporter))
  end
end
