# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mongo'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'mongo patch test' do
  puts "\n\033[1m=== TEST RUN MONGO PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  it 'does not prepend the SWO mongo patch to Mongo::Server::ConnectionBase when tag_sql is false' do
    SolarWindsAPM::Config[:tag_sql] = false
    SolarWindsAPM::OTelConfig.initialize

    connection_ancestors = Mongo::Server::ConnectionBase.ancestors.map(&:to_s)
    refute_includes connection_ancestors, 'SolarWindsAPM::Patch::TagSql::SWOMongoPatch'
  end
end
