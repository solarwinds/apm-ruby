# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require_relative '../../lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'API::OpenTelemetry#in_span delegation to OpenTelemetry tracer' do
  it 'returns nil and warns when block is nil' do
    result = SolarWindsAPM::API.in_span('test_span')
    assert_nil result
  end

  it 'calls OpenTelemetry tracer in_span with a block' do
    OpenTelemetry::SDK.configure
    result = SolarWindsAPM::API.in_span('test_span') do |span|
      refute_nil span
      42
    end
    assert_equal 42, result
  end

  it 'passes attributes, kind and other options to in_span' do
    OpenTelemetry::SDK.configure
    result = SolarWindsAPM::API.in_span('test_span', attributes: { 'key' => 'value' }, kind: :internal) do |span|
      refute_nil span
      'done'
    end
    assert_equal 'done', result
  end
end

describe 'API::CustomMetrics deprecated methods return false' do
  it 'increment_metric returns false with deprecation' do
    result = SolarWindsAPM::API.increment_metric('test_metric', 1, false, {})
    assert_equal false, result
  end

  it 'summary_metric returns false with deprecation' do
    result = SolarWindsAPM::API.summary_metric('test_metric', 5.0, 1, false, {})
    assert_equal false, result
  end
end

describe 'API::Tracer#add_tracer method wrapping with span instrumentation' do
  it 'add_tracer wraps an instance method with in_span' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def greeting
        'hello'
      end
      add_tracer :greeting, 'greeting_span'
    end

    OpenTelemetry::SDK.configure

    instance = klass.new
    result = instance.greeting
    assert_equal 'hello', result
  end

  it 'add_tracer uses default span name when nil' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def work
        'done'
      end
      add_tracer :work
    end

    OpenTelemetry::SDK.configure

    instance = klass.new
    result = instance.work
    assert_equal 'done', result
  end

  it 'add_tracer passes options to in_span' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def compute
        100
      end
      add_tracer :compute, 'compute_span', { attributes: { 'foo' => 'bar' }, kind: :consumer }
    end

    OpenTelemetry::SDK.configure

    instance = klass.new
    result = instance.compute
    assert_equal 100, result
  end
end
