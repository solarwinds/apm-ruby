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
    ENV.delete('OBOE_ENV')
  end

  it 'simple_extconf_test_with_OBOE_DEBUG_and_OBOE_ENV_nil' do
    ENV['OBOE_DEBUG'] = 'true'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    assert_includes output, 'Fetching DEBUG Build based on prod'
    assert_match(%r{https://agent-binaries\.cloud\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)/relwithdebinfo}, output)

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_with_OBOE_DEBUG_and_OBOE_ENV_empty' do
    ENV['OBOE_DEBUG'] = 'true'
    ENV['OBOE_ENV'] = ''
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    assert_includes output, 'Fetching DEBUG Build based on prod'
    assert_match(%r{https://agent-binaries\.cloud\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)/relwithdebinfo}, output)

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_with_OBOE_DEBUG_and_OBOE_ENV_prod' do
    ENV['OBOE_DEBUG'] = 'true'
    ENV['OBOE_ENV'] = 'prod'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    assert_includes output, 'Fetching DEBUG Build based on prod'
    assert_match(%r{https://agent-binaries\.cloud\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)/relwithdebinfo}, output)

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_with_OBOE_DEBUG_and_OBOE_ENV_stg' do
    ENV['OBOE_DEBUG'] = 'true'
    ENV['OBOE_ENV'] = 'stg'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from STAGING Build'
    assert_includes output, 'Fetching DEBUG Build based on stg'
    assert_match(%r{https://agent-binaries\.global\.st-ssp\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)/relwithdebinfo}, output)

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_with_OBOE_DEBUG_and_OBOE_ENV_dev' do
    ENV['OBOE_DEBUG'] = 'true'
    ENV['OBOE_ENV'] = 'dev'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from DEVELOPMENT Build'
    assert_includes output, 'Fetching DEBUG Build based on dev'
    assert_includes output, 'https://solarwinds-apm-staging.s3.us-west-2.amazonaws.com/apm/c-lib/nightly/relwithdebinfo'

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_without_OBOE_DEBUG_and_OBOE_ENV_dev' do
    ENV['OBOE_ENV'] = 'dev'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from DEVELOPMENT Build'
    refute_includes output, 'Fetching DEBUG Build based on dev'
    assert_includes output, 'https://solarwinds-apm-staging.s3.us-west-2.amazonaws.com/apm/c-lib/nightly'

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_without_OBOE_DEBUG_and_OBOE_ENV_stg' do
    ENV['OBOE_ENV'] = 'stg'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from STAGING Build'
    refute_includes output, 'Fetching DEBUG Build based on stg'
    assert_match(%r{https://agent-binaries\.global\.st-ssp\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)}, output)

    refute_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_without_OBOE_DEBUG_and_OBOE_ENV_prod' do
    ENV['OBOE_ENV'] = 'prod'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    refute_includes output, 'Fetching DEBUG Build based on prod'
    assert_match(%r{https://agent-binaries\.cloud\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)}, output)

    assert_includes output, 'Checksum Verification Fail'
  end

  it 'simple_extconf_test_without_OBOE_DEBUG_and_OBOE_ENV_nowhere' do
    ENV['OBOE_ENV'] = 'nowhere'
    output = stub_for_mkmf_test
    assert_includes output, 'Fetching c-lib from PRODUCTION Build'
    refute_includes output, 'Fetching DEBUG Build based on prod'
    assert_match(%r{https://agent-binaries\.cloud\.solarwinds\.com/apm/c-lib/(\d+\.\d+\.\d+)}, output)

    assert_includes output, 'Checksum Verification Fail'
  end
end
