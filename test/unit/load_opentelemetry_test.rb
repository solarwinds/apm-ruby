# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
    SolarWindsOTelAPM::Config[:otel_propagator] = nil
    ENV["SWO_OTEL_PROPAGATOR"] = nil
    @@config = {}
  end

  it 'test_resolve_propagators_with_defaults' do
    SolarWindsOTelAPM::Config[:otel_propagator] = nil
    ENV["SWO_OTEL_PROPAGATOR"] = nil
    SolarWindsOTelAPM::OTelConfig.initialize

    SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.stub(:new, :solarwinds_propagator) do
      ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.stub(:new, :tracecontext_propagator) do
        ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.stub(:new, :baggage_propagator) do
          SolarWindsOTelAPM::OTelConfig.send(:resolve_propagators)

          _(SolarWindsOTelAPM::OTelConfig[:propagators]).must_equal [:tracecontext_propagator, :baggage_propagator, :solarwinds_propagator]
        
        end
      end
    end
  end

  it 'test_resolve_propagators_with_env' do
    SolarWindsOTelAPM::Config[:otel_propagator] = nil
    ENV["SWO_OTEL_PROPAGATOR"] = 'tracecontext'
    SolarWindsOTelAPM::OTelConfig.initialize

    SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.stub(:new, :solarwinds_propagator) do
      ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.stub(:new, :tracecontext_propagator) do
        ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.stub(:new, :baggage_propagator) do
          SolarWindsOTelAPM::OTelConfig.send(:resolve_propagators)

          _(SolarWindsOTelAPM::OTelConfig[:propagators]).must_equal [:tracecontext_propagator]
        
        end
      end
    end
  end

  it 'test_resolve_propagators_with_config' do
    SolarWindsOTelAPM::Config[:otel_propagator] = 'baggage,solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize

    SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.stub(:new, :solarwinds_propagator) do
      ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.stub(:new, :tracecontext_propagator) do
        ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.stub(:new, :baggage_propagator) do
          SolarWindsOTelAPM::OTelConfig.send(:resolve_propagators)

          _(SolarWindsOTelAPM::OTelConfig[:propagators]).must_equal [:baggage_propagator, :solarwinds_propagator]
        
        end
      end
    end
  end


end

