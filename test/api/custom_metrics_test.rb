# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/api'

describe 'SolarWinds Custom Metrics Test' do
  it 'test_increment_metric_with_single_variable_with_successful_liboboe_metric_call' do
    SolarWindsAPM::CustomMetrics.stub(:increment, 0) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.increment_metric('abc')
        _(result).must_equal true
      end
    end
  end

  it 'test_increment_metric_with_single_variable_with_failed_liboboe_metric_call' do
    SolarWindsAPM::CustomMetrics.stub(:increment, 1) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.increment_metric('abc')
        _(result).must_equal false
      end
    end
  end

  it 'test_increment_metric_with_single_variable_with_success_variables' do
    SolarWindsAPM::CustomMetrics.stub(:increment, 0) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.increment_metric('abc', 1, true, {})
        _(result).must_equal true
      end
    end
  end

  it 'test_summary_metric_with_single_variable_with_success' do
    SolarWindsAPM::CustomMetrics.stub(:summary, 0) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.summary_metric('abc', 1, true, {})
        _(result).must_equal true
      end
    end
  end

  it 'test_summary_metric_with_single_variable_with_failure' do
    SolarWindsAPM::CustomMetrics.stub(:summary, 1) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.summary_metric('abc', 1, true, {})
        _(result).must_equal false
      end
    end
  end

  it 'test_summary_metric_with_single_variable_with_failure' do
    SolarWindsAPM::CustomMetrics.stub(:summary, 0) do
      SolarWindsAPM::MetricTags.stub(:new, {}) do
        result = SolarWindsAPM::API.summary_metric('abc', 7.7, 1, true, {})
        _(result).must_equal true
      end
    end
  end
end
