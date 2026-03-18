# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/dice_test.rb

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/dice'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'

describe 'SolarWindsAPM Dice Test' do
  it 'gives sensible rate over time' do
    dice = SolarWindsAPM::Dice.new(scale: 100, rate: 50)

    trues = 0
    falses = 0

    1000.times do
      if dice.roll
        trues += 1
      else
        falses += 1
      end
    end

    # Expecting the difference to be within 100 (i.e., between 40%-60%)
    assert (trues - falses).abs < 100, "Difference was too large: #{trues} vs #{falses}"
  end

  it 'defaults to zero and never succeeds' do
    dice = SolarWindsAPM::Dice.new(scale: 100)
    1000.times do
      refute dice.roll
    end
  end

  it 'always succeeds with full rate' do
    dice = SolarWindsAPM::Dice.new(scale: 100, rate: 100)
    1000.times do
      assert dice.roll
    end
  end

  it 'can be updated' do
    dice = SolarWindsAPM::Dice.new(scale: 100, rate: 100)
    500.times { assert dice.roll }

    dice.update(rate: 0)
    500.times { refute dice.roll }
  end
end

describe 'Dice rate clamping, update behavior, and default scale' do
  it 'rate setter clamps to scale' do
    dice = SolarWindsAPM::Dice.new(scale: 100, rate: 50)
    dice.rate = 200
    assert_equal 100, dice.rate

    dice.rate = -10
    assert_equal 0, dice.rate
  end

  it 'update changes both rate and scale' do
    dice = SolarWindsAPM::Dice.new(scale: 100, rate: 50)
    dice.update(scale: 200, rate: 150)
    assert_equal 200, dice.scale
    assert_equal 150, dice.rate
  end

  it 'defaults to scale 1_000_000' do
    dice = SolarWindsAPM::Dice.new({})
    assert_equal 1_000_000, dice.scale
    assert_equal 0, dice.rate
  end
end

describe 'TokenBucket accessors and update with various input types and edge cases' do
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
