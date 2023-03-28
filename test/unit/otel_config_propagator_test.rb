# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
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

  it 'test_propagator_sample' do

    ENV["OTEL_PROPAGATORS"] = 'tracecontext,baggage,solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
  end


  # propagation in_code testing
  it 'test_resolve_propagators_with_in_code' do
    
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = []
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false

  end

  it 'test_resolve_propagators_with_in_code_correct' do

    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
  end

  it 'test_resolve_propagators_with_in_code_misorder' do
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@solarwinds,@tracecontext,@baggage]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
  end

  it 'test_resolve_propagators_with_in_code_with_invalid_propagator' do

    dummy = String.new
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds,dummy]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
  end

  it 'test_resolve_propagators_with_in_code_with_valid_propagator' do

    dummy = Dummy::TextMapPropagator.new
    SolarWindsOTelAPM::OTelConfig.initialize do |config|
      config['OpenTelemetry::Propagators'] = [@tracecontext,@baggage,@solarwinds,dummy]
    end

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
  end

  # propagation variable testing
  it 'test_resolve_propagators_with_defaults' do
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
  end

  # propagation variable testing
  it 'test_resolve_propagators_with_valid_input' do
    ENV["OTEL_PROPAGATORS"] = 'tracecontext,baggage,solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
  end

  it 'test_resolve_propagators_with_defaults_misorder' do
    ENV["OTEL_PROPAGATORS"] = 'solarwinds,tracecontext,baggage'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
  end

  it 'test_resolve_propagators_with_defaults_invalid' do
    ENV["OTEL_PROPAGATORS"] = 'tracecontext,baggage,solarwinds,dummy'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
  end

end

