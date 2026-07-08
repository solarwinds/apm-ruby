# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/support'
require './lib/solarwinds_apm/patch/tag_sql/sw_dbo_utils'
require './lib/solarwinds_apm/patch/tag_sql/sw_mongo_patch'

# rubocop:disable Naming/MethodName
module SolarWindsAPM
  module Span
    def self.createSpan(trans_name, domain, span_time, has_error); end
  end
end
# rubocop:enable Naming/MethodName

# MongoDB and its OpenTelemetry instrumentation are not available in the test
# environment, so stub the two patch targets to exercise the real patch modules
# without a live MongoDB connection.
class FakeMongoOperationTracer
  def execute_with_span(_span, operation)
    operation
  end
end
FakeMongoOperationTracer.prepend(SolarWindsAPM::Patch::TagSql::SWOMongoPatch)

# Stub the Mongo::Protocol::Msg class so the patch's type check passes.
module Mongo
  module Protocol
    class Msg
      def initialize(main_document = {})
        @main_document = main_document
      end
    end
  end
end

class FakeMongoConnectionBase
  def deliver(message, _context, _options = {})
    message
  end
end
FakeMongoConnectionBase.prepend(SolarWindsAPM::Patch::TagSql::SWOMongoPatchV2220)

describe 'mongo patch integrate test' do
  puts "\n\033[1m=== TEST RUN MONGO PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }

  before do
    OpenTelemetry::SDK.configure
    OpenTelemetry.tracer_provider.add_span_processor(span_processor)
    @tracer = OpenTelemetry.tracer_provider.tracer('mongo-patch-test')
  end

  it 'injects traceparent comment into the operation spec and sets sw.query_tag attribute' do
    operation = Struct.new(:spec).new({})

    @tracer.in_span('mongo-op') do |_span|
      FakeMongoOperationTracer.new.execute_with_span(nil, operation)
    end

    finished_spans = exporter.finished_spans

    pattern = %r{/\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, finished_spans[0].attributes['sw.query_tag'], "Doesn't match sw.query_tag"
    assert_match pattern, operation.spec[:comment], "operation comment doesn't contain traceparent"
  end

  it 'appends traceparent comment when the operation already has a comment' do
    operation = Struct.new(:spec).new({ comment: 'existing' })

    @tracer.in_span('mongo-op') do |_span|
      FakeMongoOperationTracer.new.execute_with_span(nil, operation)
    end

    pattern = %r{^existing; /\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, operation.spec[:comment], "operation comment doesn't append traceparent"
  end

  it 'injects traceparent comment into the message main document and sets sw.query_tag attribute' do
    message = Mongo::Protocol::Msg.new({})

    @tracer.in_span('mongo-op') do |_span|
      FakeMongoConnectionBase.new.deliver(message, nil)
    end

    finished_spans = exporter.finished_spans

    main_doc = message.instance_variable_get(:@main_document)
    pattern = %r{/\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, finished_spans[0].attributes['sw.query_tag'], "Doesn't match sw.query_tag"
    assert_match pattern, main_doc['comment'], "message comment doesn't contain traceparent"
  end

  it 'appends traceparent comment when the message main document already has a comment' do
    message = Mongo::Protocol::Msg.new({ 'comment' => 'existing' })

    @tracer.in_span('mongo-op') do |_span|
      FakeMongoConnectionBase.new.deliver(message, nil)
    end

    main_doc = message.instance_variable_get(:@main_document)
    pattern = %r{^existing; /\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, main_doc['comment'], "message comment doesn't append traceparent"
  end
end
