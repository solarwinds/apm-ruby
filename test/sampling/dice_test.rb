# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/dice_test.rb

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/dice'

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
