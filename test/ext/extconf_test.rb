# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'mkmf'
require 'minitest_helper'
require 'minitest/mock'
require 'uri'
require 'open-uri'

describe 'extconf test' do
  after do
    ENV.delete('OBOE_DEBUG')
    ENV.delete('OBOE_STAGING')
    ENV.delete('OBOE_DEV')
  end

  it 'simple_extconf_test_with_OBOE_DEBUG' do
    ENV['OBOE_DEBUG'] = 'true'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION DEBUG Build'
  end

  it 'OBOE_DEBUG_surpass_other_env' do
    ENV['OBOE_DEBUG'] = 'true'
    ENV['OBOE_STAGING'] = 'true'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION DEBUG Build'
  end

  it 'simple_extconf_test_with_OBOE_STAGING' do
    ENV['OBOE_STAGING'] = 'true'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from STAGING Build'
  end

  it 'simple_extconf_test_with_OBOE_DEV' do
    ENV['OBOE_DEV'] = 'true'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from DEVELOPMENT Build'
  end

  it 'simple_extconf_test_with_no_env_variable' do
    ENV.delete('OBOE_STAGING')
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    assert_includes output, 'Checksum Verification Fail'
  end
end
