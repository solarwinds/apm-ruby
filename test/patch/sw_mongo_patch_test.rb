# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'mongo patch test' do
  puts "\n\033[1m=== TEST RUN MONGO PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  it 'does not prepend the SWO mongo patch when tag_sql is false' do
    SolarWindsAPM::Config[:tag_sql] = false
    SolarWindsAPM::OTelConfig.initialize

    if defined?(Mongo::Tracing::OpenTelemetry::OperationTracer) && Gem::Version.new(Mongo::VERSION) >= Gem::Version.new('2.23.0')
      tracer_ancestors = Mongo::Tracing::OpenTelemetry::OperationTracer.ancestors
      refute_includes tracer_ancestors, SolarWindsAPM::Patch::TagSql::SWOMongoPatch
    elsif defined?(OpenTelemetry::Instrumentation::Mongo::CommandSerializer) && Gem::Version.new(Mongo::VERSION) < Gem::Version.new('2.23.0')
      connection_ancestors = Mongo::Server::ConnectionBase.ancestors
      refute_includes connection_ancestors, SolarWindsAPM::Patch::TagSql::SWOMongoPatchV2220
    else
      skip 'MongoDB instrumentation is not available in this environment'
    end
  end
end
