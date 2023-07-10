# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
    clean_old_setting
    SolarWindsAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config_map, {})
    sleep 1
  end

  after do 
    clean_old_setting
  end

  # propagation in_code testing
  it 'test_propagators_with_default' do
    SolarWindsAPM::OTelConfig.initialize

    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 3
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  # propagation in_code testing
  it 'test_propagators_with_extra_propagators_from_otel' do
    ENV['OTEL_PROPAGATORS'] = 'b3,tracecontext,baggage'
    SolarWindsAPM::OTelConfig.initialize

    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 4
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Propagator::B3::Single::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[3].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  it 'test_propagators_without_tracecontext' do
    ENV['OTEL_PROPAGATORS'] = 'baggage'
    SolarWindsAPM::OTelConfig.initialize

    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)).must_equal nil
  end

  it 'test_propagators_without_baggage' do
    ENV['OTEL_PROPAGATORS'] = 'tracecontext'
    SolarWindsAPM::OTelConfig.initialize

    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)).must_equal nil
  end

  it 'test_propagators_with_wrong_otel_propagation' do
    ENV['OTEL_PROPAGATORS'] = 'tracecontext,baggage,abcd'
    SolarWindsAPM::OTelConfig.initialize

    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 4
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal ::OpenTelemetry::SDK::Configurator::NoopTextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[3].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end
end
