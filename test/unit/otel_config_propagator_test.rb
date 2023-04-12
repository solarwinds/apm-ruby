# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
    ENV.delete('OTEL_TRACES_EXPORTER')
    SolarWindsOTelAPM::Config[:otel_exporter] = nil

    ENV.delete('OTEL_PROPAGATORS')

    @tracecontext = ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new
    @baggage      = ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new
    @solarwinds   = SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new

    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config_map, {})
    sleep 1
  end

  after do 
    ENV.delete('OTEL_PROPAGATORS')
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsOTelAPM::OTelConfig.class_variable_set(:@@config_map, {})
    sleep 5
  end

  # propagation in_code testing
  it 'test_resolve_propagators_with_in_code' do
    
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = []
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil

  end

  it 'test_resolve_propagators_with_in_code_correct' do

    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  it 'test_resolve_propagators_with_in_code_misorder' do
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@solarwinds,@tracecontext,@baggage]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

  it 'test_resolve_propagators_with_in_code_with_invalid_propagator' do

    dummy = String.new
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds,dummy]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

  it 'test_resolve_propagators_with_in_code_with_valid_propagator' do

    dummy = Dummy::TextMapPropagator.new
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds,dummy]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][3].class).must_equal Dummy::TextMapPropagator
  end

  # propagation variable testing
  it 'test_resolve_propagators_with_defaults' do
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  # propagation variable testing
  it 'test_resolve_propagators_with_valid_input' do
    ENV["OTEL_PROPAGATORS"] = 'tracecontext,baggage,solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  it 'test_resolve_propagators_with_defaults_misorder' do
    ENV["OTEL_PROPAGATORS"] = 'solarwinds,tracecontext,baggage'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

  it 'test_resolve_propagators_with_defaults_invalid' do
    ENV["OTEL_PROPAGATORS"] = 'tracecontext,baggage,solarwinds,dummy'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

  # propagation variable from config file
  it 'test_resolve_propagators_with_defaults_from_config' do
    SolarWindsOTelAPM::Config[:otel_propagator] = 'tracecontext,baggage,solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators][2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  it 'test_resolve_propagators_with_misorder_from_config' do
    SolarWindsOTelAPM::Config[:otel_propagator] = 'solarwinds,tracecontext,baggage'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

  it 'test_resolve_propagators_with_wrong_propagator_from_config' do
    SolarWindsOTelAPM::Config[:otel_propagator] = 'tracecontext,baggage,solarwinds,dummy'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators]).must_equal nil
  end

end

