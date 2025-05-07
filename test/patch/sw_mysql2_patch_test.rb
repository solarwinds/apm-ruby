# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_native_config'

describe 'mysql2 patch test' do
  puts "\n\033[1m=== TEST RUN MYSQL2 PATCH TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  it 'mysql_patch_order_test_when_tag_sql_is_false' do
    SolarWindsAPM::Config[:tag_sql] = false
    SolarWindsAPM::OTelNativeConfig.initialize

    client_ancestors = Mysql2::Client.ancestors
    _(client_ancestors[0]).must_equal OpenTelemetry::Instrumentation::Mysql2::Patches::Client
    _(client_ancestors[1]).must_equal Mysql2::Client
  end
end
