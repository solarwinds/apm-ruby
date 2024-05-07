# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/opentelemetry'
require './lib/solarwinds_apm/support/txn_name_manager'
require './lib/solarwinds_apm/otel_lambda_config'

describe 'lambda environment configuration' do
  it 'verify_otlp_metrics_exporter_trace_exporter_and_otlp_processor' do
    SolarWindsAPM::OTelLambdaConfig.initialize
  end
end
