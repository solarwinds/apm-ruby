# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Loading Opentelemetry Test' do

  before do
    SolarWindsOTelAPM::Config[:otel_propagator] = nil
    ENV["SWO_OTEL_PROPAGATOR"] = nil
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

  it 'test_should_set_solarwinds_processor_when_swo_otel_processor_is_solarwinds' do
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig[:span_processor]).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor
  end

  it 'test_should_set_solarwinds_exporter_when_swo_otel_exporter_is_solarwinds' do
    ENV['SWO_OTEL_EXPORTER'] = 'solarwinds'
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig[:exporter]).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter
  end

  it 'test_should_set_default_exporter_and_warn_when_swo_otel_exporter_is_not_solarwinds' do 
    ENV.delete('SWO_OTEL_EXPORTER')
    SolarWindsOTelAPM::OTelConfig.initialize
    _(SolarWindsOTelAPM::OTelConfig[:exporter]).must_equal SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter

  end

end

