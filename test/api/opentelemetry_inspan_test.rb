# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Set Transaction Name Test' do
  before do
    ENV['OTEL_SERVICE_NAME'] = 'my_service'
    @op = -> { 10.times {[9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort} }
    @in_memory_exporter = CustomInMemorySpanExporter.new(recording: false)

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@in_memory_exporter))
    end
  end

  after do
    ENV['OTEL_SERVICE_NAME'] = nil
  end

  it 'test_in_span_wrapper_from_solarwinds_apm' do
    @in_memory_exporter.recording = true
    SolarWindsAPM::API.in_span('custom_span') do
      @op.call
    end

    finished_spans = @in_memory_exporter.finished_spans

    _(finished_spans.first.name).must_equal 'custom_span'
  end

  it 'test_in_span_wrapper_from_solarwinds_apm_with_span' do
    @in_memory_exporter.recording = true
    SolarWindsAPM::API.in_span('custom_span') do |span|
      span.add_attributes({"test_attribute" => "attribute_1"})
      @op.call
    end

    finished_spans = @in_memory_exporter.finished_spans

    _(finished_spans.first.name).must_equal 'custom_span'
    _(finished_spans.first.attributes['test_attribute']).must_equal 'attribute_1'
  end

  it 'test_in_span_wrapper_from_solarwinds_apm_without_block' do
    @in_memory_exporter.recording = true
    SolarWindsAPM::API.in_span('custom_span')

    finished_spans = @in_memory_exporter.finished_spans
    _(finished_spans.size).must_equal 0
  end
end
