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
    @dummy_span = create_span
    @dummy_span.context.instance_variable_set(:@span_id, 'fake_span_id') # with fake span_id, should still find the right root span
    SolarWindsAPM::OTelConfig.initialize
    @processors = ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
    puts "@processors: #{@processors.inspect}"
    @solar_processor = nil
    @processors.each do |processor|
      @solar_processor = processor if processor.instance_of?(SolarWindsAPM::OpenTelemetry::SolarWindsProcessor)
    end
    @solarwinds_processor = @solar_processor || @processors.last
    @solarwinds_processor.txn_manager.del("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")
  end

  after do
    @span.context.trace_flags.instance_variable_set(:@flags, 0)
  end

  it 'calculate_transaction_names_with_unsampled_span' do
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('abcdf')
      _(result).must_equal false
    end
    _(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")).must_equal "abcdf"
  end

  it 'calculate_transaction_names_with_empty_transaction_name' do
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('')
      _(result).must_equal false
    end
    assert_nil(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018"))
  end

  it 'calculate_transaction_names_with_sampled_span' do
    @span.context.trace_flags.instance_variable_set(:@flags, 1)
    @solarwinds_processor.on_start(@span, ::OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('abcdf')
      _(result).must_equal true
    end
    _(@solarwinds_processor.txn_manager.get("77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018")).must_equal "abcdf"
  end
end
