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

describe 'mysql2 patch integrate test' do
  puts "\n\033[1m=== TEST RUN MYSQL2 PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:sdk) { OpenTelemetry::SDK }
  let(:exporter) { sdk::Trace::Export::InMemorySpanExporter.new }
  let(:span_processor) { sdk::Trace::Export::SimpleSpanProcessor.new(exporter) }
  let(:finished_spans) { exporter.finished_spans }

  it 'tag_sql_mysql2_integrate_test' do
    require './lib/solarwinds_apm/patch/tag_sql/sw_mysql2_patch'

    OpenTelemetry::SDK.configure(&:use_all)
    OpenTelemetry.tracer_provider.add_span_processor(span_processor)

    client_ancestors = Mysql2::Client.ancestors
    _(client_ancestors[0]).must_equal OpenTelemetry::Instrumentation::Mysql2::Patches::Client
    _(client_ancestors[1]).must_equal SolarWindsAPM::Patch::TagSql::SWOMysql2Patch
    _(client_ancestors[2]).must_equal Mysql2::Client

    mysql2_client = Mysql2::Client.new
    sql = mysql2_client.query('SELECT * FROM ABC;')

    pattern = %r{/\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, finished_spans[0].attributes['sw.query_tag'], "Doesn't match sw.query_tag"

    pattern = %r{^SELECT \* FROM ABC;\s+/\*traceparent='[\da-f-]+'*\*/$}
    assert_match pattern, sql, "Sql doesn't contain traceparent"
  end
end
