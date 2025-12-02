# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'

# TokenBucketSettings = Struct.new(:capacity,:rate,:interval)
describe 'SolarWindsAPM::TokenBucket' do
  it 'starts full' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 10))
    assert bucket.consume(2)
  end

  it "can't consume more than it contains" do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 1, 10))
    refute bucket.consume(2)
    assert bucket.consume
  end

  it 'replenishes over time' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 10))
    assert bucket.consume(2)

    bucket.start
    sleep(0.05)
    bucket.stop
    assert bucket.consume(2)
  end

  # error: the token size is more than capacity
  it "doesn't replenish more than its capacity" do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 10))
    assert bucket.consume(2)

    bucket.start
    sleep(0.1)
    bucket.stop
    refute bucket.consume(4)
  end

  it 'can be updated' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 1, 10))
    refute bucket.consume(2)

    bucket.update(capacity: 2)
    assert bucket.consume(2)
  end

  it 'decreases tokens to capacity when updating to a lower one' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 10))
    bucket.update(capacity: 1)
    refute bucket.consume(2)
  end

  it 'can be updated while running' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(8, 0, 10))
    assert bucket.consume(8)
    bucket.start

    bucket.update(rate: 2, interval: 5)
    sleep(0.1)
    bucket.stop
    assert bucket.consume(8)
  end

  it 'defaults to zero' do
    # default interval is ~24 days, not suitable for testing
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(0, 0, 1000))

    bucket.start
    sleep(0.1)
    bucket.stop

    refute bucket.consume
  end
end
