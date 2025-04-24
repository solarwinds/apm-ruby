# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative '../../lib/solarwinds_apm/config'
require_relative '../../lib/solarwinds_apm/support/txn_name_manager'
require_relative '../../lib/solarwinds_apm/otel_native_config'

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/api/set_transaction_name_test.rb
describe 'SolarWinds Set Transaction Name Test' do
  before do
    @span = create_span
    @dummy_span = create_span
    @dummy_span.context.instance_variable_set(:@span_id, 'fake_span_id') # with fake span_id, should still find the right root span
    SolarWindsAPM::OTelNativeConfig.initialize
    @solarwinds_processor = SolarWindsAPM::OTelNativeConfig[:metrics_processor]
  end

  after do
    @span.context.trace_flags.instance_variable_set(:@flags, 0)
    ENV.delete('SW_APM_ENABLED')
  end

  it 'set_transaction_name_when_not_sampled' do
    @solarwinds_processor.on_start(@span, OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('abcdf')
      _(result).must_equal true
    end
    _(@solarwinds_processor.txn_manager.get('77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018')).must_equal 'abcdf'
  end

  it 'set_multiple_transaction_names_when_sampled' do
    @span.context.trace_flags.instance_variable_set(:@flags, 1)
    @solarwinds_processor.on_start(@span, OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      _(SolarWindsAPM::API.set_transaction_name('older-name')).must_equal true
      _(SolarWindsAPM::API.set_transaction_name('newer-name')).must_equal true
    end
    _(@solarwinds_processor.txn_manager.get('77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018')).must_equal 'newer-name'
  end

  it 'set_empty_transaction_name' do
    @solarwinds_processor.on_start(@span, OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('')
      _(result).must_equal false
    end
    assert_nil(@solarwinds_processor.txn_manager.get('77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018'))
  end

  it 'set_transaction_name_when_current_span_invalid' do
    @solarwinds_processor.on_start(@span, OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, OpenTelemetry::Trace::Span::INVALID) do
      result = SolarWindsAPM::API.set_transaction_name('abcdf')
      _(result).must_equal false
    end
    assert_nil(@solarwinds_processor.txn_manager.get('77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018'))
  end

  it 'set_transaction_name_when_library_noop' do
    @solarwinds_processor.on_start(@span, OpenTelemetry::Context.current)
    OpenTelemetry::Trace.stub(:current_span, @dummy_span) do
      result = SolarWindsAPM::API.set_transaction_name('abcdf')
      _(result).must_equal true
    end
    _(@solarwinds_processor.txn_manager.get('77cb6ccc522d3106114dd6ecbb70036a-31e175128efc4018')).must_equal 'abcdf'
  end

  it 'set_transaction_name_when_library_disabled' do
    ENV['SW_APM_ENABLED'] = 'false'
    result = SolarWindsAPM::API.set_transaction_name('abcdf')
    _(result).must_equal true
  end
end
