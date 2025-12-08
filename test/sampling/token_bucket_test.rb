# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'

# TokenBucketSettings = Struct.new(:capacity, :rate, :interval, :type)
# Note: rate is now tokens per second (not per interval)
describe 'SolarWindsAPM::TokenBucket' do
  it 'starts with full capacity' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 1, 1000, 'test'))
    assert bucket.consume(2)
  end

  it "can't consume more than it contains" do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 1, 1000, 'test'))
    refute bucket.consume(2)
    assert bucket.consume
  end

  it 'replenishes tokens over time based on rate' do
    # Rate of 40 tokens/second means 2 tokens in 0.05 seconds
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(10, 40, 1000, 'test'))
    assert bucket.consume(10)

    sleep(0.05)
    # Should have replenished ~2 tokens (40 * 0.05 = 2)
    assert bucket.consume(1)
    assert bucket.consume(1)
    refute bucket.consume(1) # No more tokens available
  end

  it "doesn't replenish more than its capacity" do
    # Rate of 100 tokens/second, capacity of 2
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 100, 1000, 'test'))
    assert bucket.consume(2)

    sleep(0.1)
    # Should replenish to capacity (2), not 10 tokens (100 * 0.1)
    assert bucket.consume(2)
    refute bucket.consume(1) # Can't consume more than capacity
  end

  it 'can be updated with new capacity' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1, 0, 1000, 'test'))
    refute bucket.consume(2)

    bucket.update(capacity: 2)
    assert bucket.consume(2)
  end

  it 'decreases tokens to capacity when updating to a lower one' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(2, 0, 1000, 'test'))
    bucket.update(capacity: 1)
    refute bucket.consume(2)
    assert bucket.consume(1)
  end

  it 'can update rate to change replenishment speed' do
    # Start with rate of 0 (no replenishment)
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(10, 0, 1000, 'test'))
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
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(5, 10, 1000, 'test'))
    assert bucket.consume(5)

    sleep(0.1)
    # Should have ~1 token (10 * 0.1 = 1)
    assert bucket.consume(1)

    sleep(0.2)
    # Should have ~2 more tokens (10 * 0.2 = 2)
    assert bucket.consume(2)
    refute bucket.consume(1)
  end

  it 'is thread-safe when accessing capacity and rate' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(100, 50, 1000, 'test'))

    threads = Array.new(10) do
      Thread.new do
        100.times do
          bucket.capacity
          bucket.rate
          bucket.consume(1)
        end
      end
    end

    threads.each(&:join)
    # Should complete without errors
    assert true
  end

  it 'handles concurrent updates and consumes safely' do
    bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(1000, 100, 1000, 'test'))

    consumer_threads = Array.new(5) do
      Thread.new do
        10.times { bucket.consume(1) }
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
end
