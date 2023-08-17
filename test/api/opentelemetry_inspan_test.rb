# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Set Transaction Name Test' do
  before do
    ENV['OTEL_SERVICE_NAME'] = 'my_service'
    @op = -> { 10.times {[9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort} }
    @in_memory_exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'my_service'
      c.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@in_memory_exporter))
    end
  end

  after do
    ENV['OTEL_SERVICE_NAME'] = nil
  end

  it 'test_in_span_wrapper_from_solarwinds_apm' do
    SolarWindsAPM::API.in_span('custom_span') do
      @op.call
    end

    finished_spans = @in_memory_exporter.finished_spans
    _(finished_spans.first.name).must_equal 'custom_span'
  end
end
