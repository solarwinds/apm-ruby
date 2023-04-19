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
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_exporter_with_invalid_exporter' do

    ENV["OTEL_TRACES_EXPORTER"] = 'dummy'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil
  end

  it 'test_exporter_with_solarwinds' do

    ENV["OTEL_TRACES_EXPORTER"] = 'solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_exporter_with_in_code_valid_exporter' do

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = ::OpenTelemetry::SDK::Trace::Export::SpanExporter.new
    end
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal ::OpenTelemetry::SDK::Trace::Export::SpanExporter
  end

  it 'test_exporter_with_in_code_invalid_exporter' do

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = ::OpenTelemetry::SDK::Trace::Export::SpanExporter
    end
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil
  end

  it 'test_exporter_with_in_code_invalid_exporter' do

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = Exporter::Dummy.new
    end
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil
  end

  # exporter variable from config file
  it 'test_resolve_exporter_with_solarwinds_from_config' do
    SolarWindsOTelAPM::Config[:otel_exporter] = 'solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_resolve_exporter_with_wrong_exporter_from_config' do
    SolarWindsOTelAPM::Config[:otel_exporter] = 'dummy'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil
  end

end

