# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'

describe 'SolarWinds API in_span Test' do

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

    OpenTelemetry::Context.with_current(parent_context) do
      tracer.in_span('root') do
        SolarWindsAPM::API.in_span('child1') {}
        SolarWindsAPM::API.in_span('child2') {}
        SolarWindsAPM::API.in_span('child3') do |span|
          span.add_attributes({"test_attribute" => "attribute_1"})
        end
        SolarWindsAPM::API.in_span('child4') # no block given, should ignore
      end
    end
  end

  after do
    ENV.delete('OTEL_SERVICE_NAME')
  end

  describe 'test_in_span_wrapper_from_solarwinds_apm' do
    it 'test_in_span' do
      skip if finished_spans.size == 0

      _(finished_spans.size).must_equal(4)
      _(finished_spans[0].name).must_equal('child1')
      _(finished_spans[1].name).must_equal('child2')
      _(finished_spans[2].attributes['test_attribute']).must_equal('attribute_1')
      _(finished_spans.collect(&:class).uniq).must_equal([sdk::Trace::SpanData])
    end
  end
end
