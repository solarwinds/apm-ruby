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
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/oboe_init_options'
require './lib/solarwinds_apm/patch/tag_sql/sw_dbo_utils'

# rubocop:disable Naming/MethodName
module SolarWindsAPM
  module Span
    def self.createSpan(trans_name, domain, span_time, has_error); end
  end
end
# rubocop:enable Naming/MethodName

def pg_dbo_integration_verification(sql, finished_spans)
  pattern = %r{/\*traceparent='[\da-f-]+'*\*/$}
  assert_match pattern, finished_spans[0].attributes['sw.query_tag'], "Doesn't match sw.query_tag"

  pattern = %r{^SELECT \* FROM ABC;\s+/\*traceparent='[\da-f-]+'*\*/$}
  assert_match pattern, sql, "Sql doesn't contain traceparent"
end

describe 'pg patch integrate test' do
  puts "\n\033[1m=== TEST RUN PG PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }

  it 'tag_sql_pg_integrate_test' do
    require './lib/solarwinds_apm/patch/tag_sql/sw_pg_patch'

    OpenTelemetry::SDK.configure(&:use_all)
    OpenTelemetry.tracer_provider.add_span_processor(span_processor)

    client_ancestors = PG::Connection.ancestors
    _(client_ancestors[0]).must_equal OpenTelemetry::Instrumentation::PG::Patches::Connection
    _(client_ancestors[1]).must_equal SolarWindsAPM::Patch::TagSql::SWOPgPatch
    _(client_ancestors[2]).must_equal PG::Connection

    pg_client = PG::Connection.new

    args = ['SELECT * FROM ABC;']

    sql = pg_client.query(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    sql = pg_client.exec(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    sql = pg_client.sync_exec(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    sql = pg_client.async_exec(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    args = ['SELECT * FROM ABC;', [1]]
    sql = pg_client.exec_params(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    sql = pg_client.async_exec_params(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset

    sql = pg_client.sync_exec_params(*args)
    finished_spans = exporter.finished_spans
    pg_dbo_integration_verification(sql, finished_spans)
    exporter.reset
  end
end
