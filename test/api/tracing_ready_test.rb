# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/api'

describe 'Test solarwinds_ready API call' do

  it 'default_test_solarwinds_ready' do
    SolarWindsAPM::Context.stub(:isReady, 1) do
      _(SolarWindsAPM::API.solarwinds_ready?).must_equal true
    end
  end

  it 'solarwinds_ready_with_5000_wait_time' do
    SolarWindsAPM::Context.stub(:isReady, 1) do
      _(SolarWindsAPM::API.solarwinds_ready?(5000)).must_equal true
    end
  end

  it 'solarwinds_ready_with_5000_wait_time_and_int_response' do
    SolarWindsAPM::Context.stub(:isReady, 1) do
      _(SolarWindsAPM::API.solarwinds_ready?(5000, integer_response: true)).must_equal 1
    end
  end

  it 'solarwinds_ready_with_default_wait_time_and_int_response' do
    SolarWindsAPM::Context.stub(:isReady, 1) do
      _(SolarWindsAPM::API.solarwinds_ready?(integer_response: true)).must_equal 1
    end
  end

  it 'solarwinds_ready_with_default_wait_time_and_int_response_as_4' do
    SolarWindsAPM::Context.stub(:isReady, 4) do
      _(SolarWindsAPM::API.solarwinds_ready?(integer_response: true)).must_equal 4
    end
  end

  it 'solarwinds_ready_with_default_wait_time_and_int_response_as_false' do
    SolarWindsAPM::Context.stub(:isReady, 1) do
      _(SolarWindsAPM::API.solarwinds_ready?(integer_response: false)).must_equal true
    end
  end
end
