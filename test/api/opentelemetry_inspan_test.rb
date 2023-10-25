# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'
# act -j unit_test --container-architecture linux/arm64 -s SW_APM_SERVICE_KEY=your_key
# 

describe 'SolarWinds Set Transaction Name Test' do
  before do
    @op = -> { 10.times {[9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort} }
  end

  it 'test_in_span_wrapper_from_solarwinds_apm' do

    in_memory_exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'test_in_span_wrapper_from_solarwinds_apm'
      c.add_span_processor(
        ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
          in_memory_exporter))
    end

    SolarWindsAPM::API.in_span('custom_span') do
      @op.call
    end

    finished_spans = extract_span(in_memory_exporter)
    skip if finished_spans.size == 0

    _(finished_spans.first.name).must_equal 'custom_span'

    in_memory_exporter.shutdown
  end

  it 'test_in_span_wrapper_from_solarwinds_apm_with_span' do
    
    in_memory_exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'test_in_span_wrapper_from_solarwinds_apm_with_span'
      c.add_span_processor(
        ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
          in_memory_exporter))
    end

    SolarWindsAPM::API.in_span('custom_span') do |span|
      span.add_attributes({"test_attribute" => "attribute_1"})
      @op.call
    end

    finished_spans = extract_span(in_memory_exporter)
    skip if finished_spans.size == 0

    _(finished_spans.first.name).must_equal 'custom_span'
    _(finished_spans.first.attributes['test_attribute']).must_equal 'attribute_1'

    in_memory_exporter.shutdown
  end

  it 'test_in_span_wrapper_from_solarwinds_apm_without_block' do

    in_memory_exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'test_in_span_wrapper_from_solarwinds_apm'
      c.add_span_processor(
        ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
          in_memory_exporter))
    end

    SolarWindsAPM::API.in_span('custom_span')

    finished_spans = extract_span(in_memory_exporter)
    _(finished_spans.size).must_equal 0

    in_memory_exporter.shutdown
  end
end
