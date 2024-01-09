# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_config'

describe 'lambda environment' do

  before do
    clean_old_setting
    SolarWindsAPM::OTelConfig.class_variable_set(:@@agent_enabled, true)
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config, {})
    SolarWindsAPM::OTelConfig.class_variable_set(:@@config_map, {})
    SolarWindsAPM.is_lambda = true
  end

  after do
    SolarWindsAPM.is_lambda = false
  end

  it 'verify_otlp_metrics_exporter_trace_exporter_and_otlp_processor' do
    skip unless defined?(::OpenTelemetry::Exporter::OTLP::MetricsExporter)

    SolarWindsAPM::OTelConfig.initialize
    otel_config = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)
    _(otel_config[:span_processor].class).must_equal SolarWindsAPM::OpenTelemetry::OTLPProcessor
    _(otel_config[:metrics_exporter].class).must_equal ::OpenTelemetry::Exporter::OTLP::MetricsExporter
  end
end
