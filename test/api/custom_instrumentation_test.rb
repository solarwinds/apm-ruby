# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Custom Instrumentation Test' do
  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }
  let(:provider) do
    OpenTelemetry.tracer_provider = sdk::Trace::TracerProvider.new.tap do |provider|
      provider.add_span_processor(span_processor)
    end
  end
  let(:tracer) { provider.tracer(__FILE__, sdk::VERSION) }
  let(:parent_context) { OpenTelemetry::Context.empty }
  let(:finished_spans) { exporter.finished_spans }

  before do
    ENV['OTEL_SERVICE_NAME'] = __FILE__
  end

  after do
    ENV.delete('OTEL_SERVICE_NAME')
  end

  it 'test_custom_instrumentation_simple_case' do
    class MyClass
      include SolarWindsAPM::API::Tracer

      def new_method(param1, param2)
        param1 + param2
      end

      add_tracer :new_method
    end

    OpenTelemetry::Context.with_current(parent_context) do
      tracer.in_span('root') do
        my_class = MyClass.new
        my_class.new_method(1, 2)
      end
    end

    skip if finished_spans.empty?

    _(finished_spans.size).must_equal(2)
    _(finished_spans[0].name).must_equal('MyClass/add_tracer')
    _(finished_spans[0].kind).must_equal(:internal)
  end

  it 'test_custom_instrumentation_simple_case_with_custom_name_and_options' do
    class MyClass
      include SolarWindsAPM::API::Tracer

      def new_method(param1, param2)
        param1 + param2
      end

      add_tracer :new_method, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :consumer }
    end

    OpenTelemetry::Context.with_current(parent_context) do
      tracer.in_span('root') do
        my_class = MyClass.new
        my_class.new_method(1, 2)
      end
    end

    skip if finished_spans.empty?

    _(finished_spans[0].name).must_equal('custom_name')
    _(finished_spans[0].attributes['foo']).must_equal('bar')
    _(finished_spans[0].kind).must_equal(:consumer)
  end

  it 'test_custom_instrumentation_instance_method' do
    class MyClass
      def self.new_method(param1, param2)
        param1 + param2
      end

      class << self
        include SolarWindsAPM::API::Tracer

        add_tracer :new_method, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :unknown }
      end
    end

    OpenTelemetry::Context.with_current(parent_context) do
      tracer.in_span('root') do
        MyClass.new_method(1, 2)
      end
    end

    skip if finished_spans.empty?

    _(finished_spans[0].name).must_equal('custom_name')
    _(finished_spans[0].attributes['foo']).must_equal('bar')
    _(finished_spans[0].kind).must_equal(:unknown)
  end
end
