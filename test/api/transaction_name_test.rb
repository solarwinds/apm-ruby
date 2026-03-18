# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require_relative '../../lib/solarwinds_apm/support/txn_name_manager'
require_relative '../../lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/api'

describe 'API::TransactionName#set_transaction_name input validation and early returns' do
  before do
    @original_enabled = ENV['SW_APM_ENABLED']
  end

  after do
    if @original_enabled
      ENV['SW_APM_ENABLED'] = @original_enabled
    else
      ENV.delete('SW_APM_ENABLED')
    end
  end

  it 'returns true and logs debug when SW_APM_ENABLED is false' do
    ENV['SW_APM_ENABLED'] = 'false'
    result = SolarWindsAPM::API.set_transaction_name('test_txn')
    assert_equal true, result
  end

  it 'returns true when metrics_processor is nil' do
    ENV['SW_APM_ENABLED'] = 'true'

    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = nil

    result = SolarWindsAPM::API.set_transaction_name('test_txn')
    assert_equal true, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end

  it 'returns false for nil custom_name' do
    ENV['SW_APM_ENABLED'] = 'true'

    # Make metrics_processor non-nil for this branch
    stub_processor = Object.new
    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = stub_processor

    result = SolarWindsAPM::API.set_transaction_name(nil)
    assert_equal false, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end

  it 'returns false for empty custom_name' do
    ENV['SW_APM_ENABLED'] = 'true'

    stub_processor = Object.new
    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = stub_processor

    result = SolarWindsAPM::API.set_transaction_name('')
    assert_equal false, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end

  it 'returns false for invalid span context with valid processor and name' do
    ENV['SW_APM_ENABLED'] = 'true'

    stub_processor = Object.new
    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = stub_processor

    # Without an active span, the span context is invalid
    result = SolarWindsAPM::API.set_transaction_name('valid_name')
    assert_equal false, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end

  it 'sets transaction name within a valid span context' do
    ENV['SW_APM_ENABLED'] = 'true'

    mock_txn_manager = Object.new
    def mock_txn_manager.get_root_context_h(_trace_id)
      'abcdef1234567890-01'
    end

    def mock_txn_manager.set(_key, _value); end

    mock_processor = Object.new
    mock_processor.define_singleton_method(:txn_manager) { mock_txn_manager }

    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = mock_processor

    OpenTelemetry::SDK.configure
    tracer = OpenTelemetry.tracer_provider.tracer('test')
    result = nil
    tracer.in_span('test_span') do
      result = SolarWindsAPM::API.set_transaction_name('custom_txn')
    end
    assert_equal true, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end

  it 'returns false when root context record not found in txn_manager' do
    ENV['SW_APM_ENABLED'] = 'true'

    mock_txn_manager = Object.new
    def mock_txn_manager.get_root_context_h(_trace_id)
      nil
    end

    mock_processor = Object.new
    mock_processor.define_singleton_method(:txn_manager) { mock_txn_manager }

    original_proc = SolarWindsAPM::OTelConfig[:metrics_processor]
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = mock_processor

    OpenTelemetry::SDK.configure
    tracer = OpenTelemetry.tracer_provider.tracer('test')
    result = nil
    tracer.in_span('test_span') do
      result = SolarWindsAPM::API.set_transaction_name('custom_txn')
    end
    assert_equal false, result
  ensure
    SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:metrics_processor] = original_proc
  end
end
