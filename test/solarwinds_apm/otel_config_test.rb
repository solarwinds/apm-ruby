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

  it 'default_response_propagators' do

    SolarWindsAPM::OTelConfig.initialize
    rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
    _(rack_config.count).must_equal 1
    _(rack_config[:response_propagators][0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
  end

  it 'default_response_propagators_with_other_rack_config' do

    SolarWindsAPM::OTelConfig.initialize_with_config do |config|
      config['OpenTelemetry::Instrumentation::Rack'] = {:record_frontend_span => true}
    end
    rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
    _(rack_config.count).must_equal 2
    _(rack_config[:record_frontend_span]).must_equal true
    _(rack_config[:response_propagators][0].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
  end

  it 'default_response_propagators_with_other_response_propagators' do
    SolarWindsAPM::OTelConfig.initialize_with_config do |config|
      config['OpenTelemetry::Instrumentation::Rack'] = {:response_propagators => ['String']}
    end
    rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
    _(rack_config.count).must_equal 1
    _(rack_config[:response_propagators].count).must_equal 2
    _(rack_config[:response_propagators][0]).must_equal 'String'
    _(rack_config[:response_propagators][1].class).must_equal SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator
  end

  it 'default_response_propagators_with_non_array_response_propagators' do
    SolarWindsAPM::OTelConfig.initialize_with_config do |config|
      config['OpenTelemetry::Instrumentation::Rack'] = {:response_propagators => 'String'}
    end
    rack_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)['OpenTelemetry::Instrumentation::Rack']
    _(rack_config.count).must_equal 1
    _(rack_config[:response_propagators].class).must_equal String
  end

end

