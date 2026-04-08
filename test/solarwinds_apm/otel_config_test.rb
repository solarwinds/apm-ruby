# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require './lib/solarwinds_apm/otel_config'

describe 'OTelConfig response propagator resolution, initialization validation, and config accessor' do
  describe 'resolve_response_propagator' do
    it 'creates new rack setting when none exists' do
      config_map = nil
      config_map = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)
      original = config_map['OpenTelemetry::Instrumentation::Rack']
      config_map.delete('OpenTelemetry::Instrumentation::Rack')

      SolarWindsAPM::OTelConfig.resolve_response_propagator

      rack_setting = config_map['OpenTelemetry::Instrumentation::Rack']
      refute_nil rack_setting
      assert rack_setting[:response_propagators].is_a?(Array)
      assert_equal 1, rack_setting[:response_propagators].length
    ensure
      if config_map && original
        config_map['OpenTelemetry::Instrumentation::Rack'] = original
      elsif config_map
        config_map.delete('OpenTelemetry::Instrumentation::Rack')
      end
    end

    it 'appends to existing array of response_propagators' do
      config_map = nil
      config_map = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)
      original = config_map['OpenTelemetry::Instrumentation::Rack']

      existing_propagator = Object.new
      config_map['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: [existing_propagator] }

      SolarWindsAPM::OTelConfig.resolve_response_propagator

      rack_setting = config_map['OpenTelemetry::Instrumentation::Rack']
      assert_equal 2, rack_setting[:response_propagators].length
      assert_equal existing_propagator, rack_setting[:response_propagators][0]
    ensure
      if config_map && original
        config_map['OpenTelemetry::Instrumentation::Rack'] = original
      elsif config_map
        config_map.delete('OpenTelemetry::Instrumentation::Rack')
      end
    end

    it 'sets response_propagators when nil in existing rack setting' do
      config_map = nil
      config_map = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)
      original = config_map['OpenTelemetry::Instrumentation::Rack']

      config_map['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: nil }

      SolarWindsAPM::OTelConfig.resolve_response_propagator

      rack_setting = config_map['OpenTelemetry::Instrumentation::Rack']
      assert rack_setting[:response_propagators].is_a?(Array)
      assert_equal 1, rack_setting[:response_propagators].length
    ensure
      if config_map && original
        config_map['OpenTelemetry::Instrumentation::Rack'] = original
      elsif config_map
        config_map.delete('OpenTelemetry::Instrumentation::Rack')
      end
    end

    it 'warns when response_propagators is not an Array' do
      config_map = nil
      config_map = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)
      original = config_map['OpenTelemetry::Instrumentation::Rack']

      config_map['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: 'not_an_array' }

      SolarWindsAPM::OTelConfig.resolve_response_propagator

      # Should keep original invalid type
      rack_setting = config_map['OpenTelemetry::Instrumentation::Rack']
      assert_equal 'not_an_array', rack_setting[:response_propagators]
    ensure
      if config_map && original
        config_map['OpenTelemetry::Instrumentation::Rack'] = original
      elsif config_map
        config_map.delete('OpenTelemetry::Instrumentation::Rack')
      end
    end
  end

  describe 'initialize_with_config' do
    it 'warns and returns when no block given' do
      result = SolarWindsAPM::OTelConfig.initialize_with_config
      assert_nil result
    end

    it 'warns and returns for empty config_map' do
      nil
      original_map = nil
      config_map = SolarWindsAPM::OTelConfig.class_variable_get(:@@config_map)
      original_map = config_map.dup

      config_map.clear

      result = SolarWindsAPM::OTelConfig.initialize_with_config do |_config|
        # intentionally provide nothing
      end

      assert_nil result
    ensure
      SolarWindsAPM::OTelConfig.class_variable_set(:@@config_map, original_map) if original_map
    end
  end

  describe '[] accessor' do
    it 'returns value for given key' do
      config = nil
      config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)
      config[:test_key_otel] = 'test_value'
      assert_equal 'test_value', SolarWindsAPM::OTelConfig[:test_key_otel]
    ensure
      config&.delete(:test_key_otel)
    end

    it 'returns nil for missing key' do
      assert_nil SolarWindsAPM::OTelConfig[:nonexistent_key_xyz]
    end
  end

  describe 'agent_enabled' do
    it 'returns boolean' do
      result = SolarWindsAPM::OTelConfig.agent_enabled
      assert [true, false].include?(result)
    end
  end
end
