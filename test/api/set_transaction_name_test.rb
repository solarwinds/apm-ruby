# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/otel_config'
require './lib/solarwinds_apm/constants'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Set Transaction Name Test' do
  before do
    @span = create_span
    SolarWindsAPM::OTelConfig.initialize
    @processors = ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    @solarwinds_processor = @processors.last
    @solarwinds_processor.txn_manager.del("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")
  end

  after do
    @span.context.trace_flags.instance_variable_set(:@flags, 0)
  end

  it 'calculate_transaction_names_with_unsampled_span' do
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    result = SolarWindsAPM::API.set_transaction_name('abcdf')
    _(result).must_equal false
    _(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")).must_equal "abcdf"
  end

  it 'calculate_transaction_names_with_empty_transaction_name' do
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    result = SolarWindsAPM::API.set_transaction_name('')
    _(result).must_equal false
    assert_nil(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018"))
  end

  it 'calculate_transaction_names_with_sampled_span' do
    @span.context.trace_flags.instance_variable_set(:@flags, 1)
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    result = SolarWindsAPM::API.set_transaction_name('abcdf')
    _(result).must_equal true
    _(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")).must_equal "abcdf"
  end
end