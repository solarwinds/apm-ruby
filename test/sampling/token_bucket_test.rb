# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'

describe 'SolarWindsAPM::TokenBucket' do
  it 'starts with full capacity' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 'test'))
    assert bucket.consume(2)
  end

  it "can't consume more than it contains" do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 1, 'test'))
    refute bucket.consume(2)
    assert bucket.consume
  end

  it 'replenishes tokens over time based on rate' do
    # Rate of 40 tokens/second means 2 tokens in 0.05 seconds
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(10, 40, 'test'))
    assert bucket.consume(10)

    sleep(0.05)
    # Should have replenished ~2 tokens (40 * 0.05 = 2)
    assert bucket.consume(1)
    assert bucket.consume(1)
    refute bucket.consume(1) # No more tokens available
  end

  it "doesn't replenish more than its capacity" do
    # Rate of 100 tokens/second, capacity of 2
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 100, 'test'))
    assert bucket.consume(2)

    sleep(0.1)
    # Should replenish to capacity (2), not 10 tokens (100 * 0.1)
    assert bucket.consume(2)
    refute bucket.consume(1) # Can't consume more than capacity
  end

  it 'can be updated with new capacity' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 0, 'test'))
    refute bucket.consume(2)

    bucket.update(capacity: 2)
    assert bucket.consume(2)
  end

  it 'decreases tokens to capacity when updating to a lower one' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 0, 'test'))
    bucket.update(capacity: 1)
    refute bucket.consume(2)
    assert bucket.consume(1)
  end

  it 'can update rate to change replenishment speed' do
    # Start with rate of 0 (no replenishment)
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(10, 0, 'test'))
    assert bucket.consume(10)

    # Update rate to 20 tokens/second
    bucket.update(rate: 20)
    sleep(0.1)
    # Should have replenished ~2 tokens (20 * 0.1 = 2)
    assert bucket.consume(2)
    refute bucket.consume(1) # No more tokens
  end

  it 'defaults to zero rate when not specified' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new)

    sleep(0.1)
    # With rate of 0, no tokens are replenished
    refute bucket.consume
  end

  it 'calculates tokens correctly with multiple consume calls' do
    # Rate of 10 tokens/second
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 10, 'test'))
    assert bucket.consume(5)

    sleep(0.1)
    # Should have ~1 token (10 * 0.1 = 1)
    assert bucket.consume(1)

    sleep(0.2)
    # Should have ~2 more tokens (10 * 0.2 = 2)
    assert bucket.consume(2)
    refute bucket.consume(1)
  end

  it 'is thread-safe with concurrent updates, consumes, and accessors' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1000, 100, 'test'))

    consumer_threads = Array.new(5) do
      Thread.new do
        10.times do
          bucket.capacity
          bucket.rate
          bucket.consume(1)
        end
      end
    end

    updater_threads = Array.new(2) do
      Thread.new do
        5.times { bucket.update(rate: rand(100..199)) }
      end
    end

    (consumer_threads + updater_threads).each(&:join)
    # Should complete without race conditions
    assert bucket.tokens >= 0
    assert bucket.tokens <= bucket.capacity
  end

  it 'tokens accessor returns current tokens' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'test'))
    tokens = bucket.tokens
    assert tokens <= 5
    assert tokens >= 0
  end

  it 'type accessor returns type' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'MY_TYPE'))
    assert_equal 'MY_TYPE', bucket.type
  end

  it 'update with TokenBucketSettings object' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'test'))
    new_settings = SolarWindsAPM::TokenBucketSettings.new(10, 2, 'test')
    bucket.update(new_settings)
    assert_equal 10, bucket.capacity
    assert_equal 2, bucket.rate
  end

  it 'update with hash' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'test'))
    bucket.update({ capacity: 20, rate: 5 })
    assert_equal 20, bucket.capacity
    assert_equal 5, bucket.rate
  end

  it 'update handles only rate change' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'test'))
    bucket.update({ rate: 10 })
    assert_equal 5, bucket.capacity
    assert_equal 10, bucket.rate
  end

  it 'update handles negative rate gracefully' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 1, 'test'))
    bucket.update({ rate: -5 })
    assert_equal 0, bucket.rate
  end

  it 'update handles negative capacity gracefully' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 0, 'test'))
    bucket.update({ capacity: -5 })
    assert_equal 0, bucket.capacity
  end
end
