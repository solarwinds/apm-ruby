# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Otel Config Test' do

  before do
    ENV.delete('OTEL_PROPAGATORS')
    ENV.delete('OTEL_TRACES_EXPORTER')

    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config_map, {})
    sleep 1
  end


  # propagation in_code testing
  it 'test_valid_reinitialization_on_exporter' do

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = Exporter::Dummy.new
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = ::OpenTelemetry::SDK::Trace::Export::SpanExporter.new
    end
    
    puts SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)
    puts SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal ::OpenTelemetry::SDK::Trace::Export::SpanExporter
  end

  # propagation in_code testing
  it 'test_invalid_reinitialization_on_exporter' do

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = ::OpenTelemetry::SDK::Trace::Export::SpanExporter.new
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter].class).must_equal ::OpenTelemetry::SDK::Trace::Export::SpanExporter

    SolarWindsOTelAPM::OTelConfig.reinitialize do |config|
      config['OpenTelemetry::Exporter'] = Exporter::Dummy.new
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:exporter]).must_equal nil
  end

end

