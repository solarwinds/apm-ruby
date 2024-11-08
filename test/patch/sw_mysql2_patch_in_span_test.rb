# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'
require './lib/solarwinds_apm/support/utils'

describe 'mysql2 patch test' do
  it 'mysql2_call_chain_include_patch' do
    SolarWindsAPM::Config[:tag_sql] = true
    SolarWindsAPM::OTelConfig.initialize

    client_ancestors = Mysql2::Client.ancestors
    _(client_ancestors[0]).must_equal OpenTelemetry::Instrumentation::Mysql2::Patches::Client
    _(client_ancestors[1]).must_equal SolarWindsAPM::Patch::TagSql::SWOMysql2Patch
    _(client_ancestors[2]).must_equal Mysql2::Client
  end

  describe 'tag_sql_mysql2_test_in_span' do
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

    it 'mysql_patch_order_test_with_in_span' do
      SolarWindsAPM::Config[:tag_sql] = true
      SolarWindsAPM::OTelConfig.initialize

      OpenTelemetry::Context.with_current(parent_context) do
        tracer.in_span('root') do
          mysql2_client = Mysql2::Client.new
          sql = mysql2_client.query('SELECT * FROM ABC;')
          pattern = %r{^SELECT \* FROM ABC;\s+/\*traceparent='[\da-f-]+'*\*/$}
          assert_match pattern, sql, "Sql dones't contain traceparent"
        end
      end
    end
  end
end
