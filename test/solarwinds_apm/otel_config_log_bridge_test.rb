# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'Log Bridge Initialization Test' do
  describe 'check if log bridge is enabled' do
    after do
      ENV.delete('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED')
    end

    it 'OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=true -> enabled' do
      ENV['OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED'] = 'true'
      SolarWindsAPM::OTelConfig.initialize
      _(ENV.fetch('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED', nil)).must_equal 'true'
    end

    it 'OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=false -> enabled' do
      ENV['OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED'] = 'false'
      SolarWindsAPM::OTelConfig.initialize
      _(ENV.fetch('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED', nil)).must_equal 'false'
    end

    it 'OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=empty -> disabled' do
      ENV['OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED'] = ''
      SolarWindsAPM::OTelConfig.initialize
      _(ENV.fetch('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED', nil)).must_equal 'false'
    end

    it 'OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=nil -> disabled' do
      ENV['OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED'] = nil
      SolarWindsAPM::OTelConfig.initialize
      _(ENV.fetch('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED', nil)).must_equal 'false'
    end
    it 'OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=djisdfes -> disabled' do
      ENV['OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED'] = 'djisdfes'
      SolarWindsAPM::OTelConfig.initialize
      _(ENV.fetch('OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED', nil)).must_equal 'false'
    end
  end
end
