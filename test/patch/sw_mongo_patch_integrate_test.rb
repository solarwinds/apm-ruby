# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mongo'
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

# ConnectionBase#deliver performs a live socket write, so exercise the real
# patch module through a test double that returns the delivered message. The
# mongo gem is installed for tests, so the real Mongo::Protocol::Msg is used.
class FakeMongoConnectionBase
  def deliver(message, _context, _options = {})
    message
  end
  private :deliver
end
FakeMongoConnectionBase.prepend(SolarWindsAPM::Patch::TagSql::SWOMongoPatch)

describe 'mongo patch integrate test' do
  puts "\n\033[1m=== TEST RUN MONGO PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }
  let(:traceparent_pattern) { %r{/\*traceparent='[\da-f-]+'*\*/$} }

  before do
    OpenTelemetry::SDK.configure
    OpenTelemetry.tracer_provider.add_span_processor(span_processor)
    @tracer = OpenTelemetry.tracer_provider.tracer('mongo-patch-test')
  end

  def deliver_in_span(message)
    @tracer.in_span('mongo-op') do |_span|
      FakeMongoConnectionBase.new.send(:deliver, message, nil)
    end
    message.instance_variable_get(:@main_document)
  end

  it 'injects traceparent comment into the message main document and sets sw.query_tag attribute' do
    message = Mongo::Protocol::Msg.new([], {}, {})

    main_doc = deliver_in_span(message)

    finished_spans = exporter.finished_spans
    assert_match traceparent_pattern, finished_spans[0].attributes['sw.query_tag'], "Doesn't match sw.query_tag"
    assert_match traceparent_pattern, main_doc['comment'], "message comment doesn't contain traceparent"
  end

  it 'appends traceparent comment when the message main document already has a string comment' do
    message = Mongo::Protocol::Msg.new([], {}, { 'comment' => 'existing' })

    main_doc = deliver_in_span(message)

    assert_match %r{^existing; /\*traceparent='[\da-f-]+'*\*/$}, main_doc['comment'], "message comment doesn't append traceparent"
  end

  it 'appends traceparent comment when the main document uses a symbol comment key' do
    message = Mongo::Protocol::Msg.new([], {}, { comment: 'existing' })

    main_doc = deliver_in_span(message)

    assert_match %r{^existing; /\*traceparent='[\da-f-]+'*\*/$}, main_doc[:comment], "message comment doesn't append traceparent"
  end

  it 'adds traceparent as a sibling key when the comment is a document' do
    message = Mongo::Protocol::Msg.new([], {}, { 'comment' => { 'foo' => 'bar' } })

    main_doc = deliver_in_span(message)

    comment = main_doc['comment']
    assert_instance_of BSON::Document, comment
    assert_equal 'bar', comment['foo']
    assert_match traceparent_pattern, comment['traceparent'], "document comment doesn't contain traceparent"
  end

  it 'preserves a user traceparent key by storing the trace under swo_traceparent' do
    message = Mongo::Protocol::Msg.new([], {}, { 'comment' => { 'traceparent' => 'user-value' } })

    main_doc = deliver_in_span(message)

    comment = main_doc['comment']
    assert_instance_of BSON::Document, comment
    assert_equal 'user-value', comment['traceparent']
    assert_match traceparent_pattern, comment['swo_traceparent'], "document comment doesn't preserve user traceparent"
  end

  it 'wraps a scalar comment in a document with the original value' do
    message = Mongo::Protocol::Msg.new([], {}, { 'comment' => 42 })

    main_doc = deliver_in_span(message)

    comment = main_doc['comment']
    assert_instance_of BSON::Document, comment
    assert_equal 42, comment['swo_original_comment']
    assert_match traceparent_pattern, comment['traceparent'], "scalar comment doesn't contain traceparent"
  end
end
