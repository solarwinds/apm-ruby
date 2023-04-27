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

  # propagation in_code testing
  it 'test_propagators_with_default' do
    SolarWindsOTelAPM::OTelConfig.initialize

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 3
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  # propagation in_code testing
  it 'test_propagators_with_extra_propagators_from_otel' do
    ENV['OTEL_PROPAGATORS'] = 'b3,tracecontext,baggage'
    SolarWindsOTelAPM::OTelConfig.initialize

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 4
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Propagator::B3::Single::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[3].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end

  it 'test_propagators_without_tracecontext' do
    ENV['OTEL_PROPAGATORS'] = 'baggage'
    SolarWindsOTelAPM::OTelConfig.initialize

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)).must_equal nil
  end

  it 'test_propagators_without_baggage' do
    ENV['OTEL_PROPAGATORS'] = 'tracecontext'
    SolarWindsOTelAPM::OTelConfig.initialize

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal false
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)).must_equal nil
  end

  it 'test_propagators_with_wrong_otel_propagation' do
    ENV['OTEL_PROPAGATORS'] = 'tracecontext,baggage,abcd'
    SolarWindsOTelAPM::OTelConfig.initialize

    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@agent_enabled)).must_equal true
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators).count).must_equal 4
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[0].class).must_equal ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[1].class).must_equal ::OpenTelemetry::Baggage::Propagation::TextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[2].class).must_equal ::OpenTelemetry::SDK::Configurator::NoopTextMapPropagator
    _(::OpenTelemetry.propagation.instance_variable_get(:@propagators)[3].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
    _(SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:propagators].class).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator
  end
end
