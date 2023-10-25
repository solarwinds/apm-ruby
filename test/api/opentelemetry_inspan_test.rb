# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Set Transaction Name Test' do

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

  describe 'test_in_span_wrapper_from_solarwinds_apm' do
    describe '#finished_spans' do
      it 'has 4' do
        _(finished_spans.size).must_equal(4)
      end

      it 'first span is child1' do
        _(finished_spans.first.name).must_equal('child1')
      end

      it 'second span is child2' do
        _(finished_spans[1].name).must_equal('child2')
      end

      it 'third span has attributes' do
        _(finished_spans[2].attributes['test_attribute']).must_equal('attribute_1')
      end

      it 'are all SpanData' do
        _(finished_spans.collect(&:class).uniq).must_equal([sdk::Trace::SpanData])
      end
    end
  end
end
