# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require_relative '../../lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'API::OpenTelemetry#in_span delegation to OpenTelemetry tracer' do
  it 'returns nil and warns when block is nil' do
    warned = false
    SolarWindsAPM.logger.stub(:warn, ->(_msg = nil, &block) { warned = true if block&.call&.include?('please provide block') }) do
      result = SolarWindsAPM::API.in_span('test_span')
      assert_nil result
    end
    assert warned, 'Expected a warning to be logged when block is nil'
  end

  it 'calls in_span with a block and asserts the return value' do
    OpenTelemetry::SDK.configure
    result = SolarWindsAPM::API.in_span('test_span') do |span|
      refute_nil span
      assert_equal 'test_span', span.name
      assert span.attributes.empty?
      assert_equal :internal, span.kind
      42
    end
    assert_equal 42, result
  end

  it 'passes attributes, kind and other options to in_span' do
    OpenTelemetry::SDK.configure
    result = SolarWindsAPM::API.in_span('test_span', attributes: { 'key' => 'value' }, kind: :internal) do |span|
      refute_nil span
      assert_equal 'test_span', span.name
      assert_equal 'value', span.attributes['key']
      assert_equal :internal, span.kind
      'done'
    end
    assert_equal 'done', result
  end
end

describe 'API::CustomMetrics deprecated methods return false' do
  it 'increment_metric returns false with deprecation' do
    warned = false
    SolarWindsAPM.logger.stub(:warn, ->(_msg = nil, &block) { warned = true if block&.call&.include?('increment_metric is deprecated') }) do
      result = SolarWindsAPM::API.increment_metric('test_metric', 1, false, {})
      assert_equal false, result
    end
    assert warned, 'Expected a deprecation warning to be logged for increment_metric'
  end

  it 'summary_metric returns false with deprecation' do
    warned = false
    SolarWindsAPM.logger.stub(:warn, ->(_msg = nil, &block) { warned = true if block&.call&.include?('summary_metric is deprecated') }) do
      result = SolarWindsAPM::API.summary_metric('test_metric', 5.0, 1, false, {})
      assert_equal false, result
    end
    assert warned, 'Expected a deprecation warning to be logged for summary_metric'
  end
end

describe 'API::Tracer#add_tracer method wrapping with span instrumentation' do
  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }

  before do
    ENV['OTEL_SERVICE_NAME'] = __FILE__
    OpenTelemetry.tracer_provider = sdk::Trace::TracerProvider.new.tap do |provider|
      provider.add_span_processor(span_processor)
    end
  end

  after do
    ENV.delete('OTEL_SERVICE_NAME')
  end

  it 'add_tracer wraps an instance method with in_span' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def greeting
        'hello'
      end
      add_tracer :greeting, 'greeting_span'
    end

    instance = klass.new
    result = instance.greeting
    assert_equal 'hello', result

    spans = exporter.finished_spans
    skip if spans.empty?
    assert_equal 1, spans.size
    assert_equal 'greeting_span', spans[0].name
    assert_equal :internal, spans[0].kind
  end

  it 'add_tracer uses default span name when nil' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def work
        'done'
      end
      add_tracer :work
    end

    instance = klass.new
    result = instance.work
    assert_equal 'done', result

    spans = exporter.finished_spans
    skip if spans.empty?
    assert_equal 1, spans.size
    assert spans[0].name.end_with?('/add_tracer'), "Expected span name to end with '/add_tracer', got #{spans[0].name}"
    assert_equal :internal, spans[0].kind
  end

  it 'add_tracer passes options to in_span' do
    klass = Class.new do
      include SolarWindsAPM::API::Tracer

      def compute
        100
      end
      add_tracer :compute, 'compute_span', { attributes: { 'foo' => 'bar' }, kind: :consumer }
    end

    instance = klass.new
    result = instance.compute
    assert_equal 100, result

    spans = exporter.finished_spans
    skip if spans.empty?
    assert_equal 1, spans.size
    assert_equal 'compute_span', spans[0].name
    assert_equal :consumer, spans[0].kind
    assert_equal 'bar', spans[0].attributes['foo']
  end
end
