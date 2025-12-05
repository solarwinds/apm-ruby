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

  describe 'when a process fork occurs' do
    it 'creates new timer thread when update is called' do
      bucket = SolarWindsAPM::TokenBucket.new(SolarWindsAPM::TokenBucketSettings.new(8, 2, 10))
      bucket.start

      parent_timer_id = bucket.instance_variable_get(:@timer).object_id
      parent_pid = Process.pid

      read_pipe, write_pipe = IO.pipe

      pid = fork do
        read_pipe.close
        # In the child process, call update which should create a new timer thread
        bucket.update(rate: 3, capacity: 100)

        current_timer_id = bucket.instance_variable_get(:@timer).object_id
        child_pid = Process.pid

        # Write results to parent
        write_pipe.puts "#{child_pid},#{current_timer_id},#{bucket.running}"
        write_pipe.close

        bucket.stop
        exit!
      end

      write_pipe.close
      result = read_pipe.read
      read_pipe.close
      Process.wait(pid)

      child_pid, current_timer_id, is_running = result.strip.split(',')
      child_pid = child_pid.to_i
      current_timer_id = current_timer_id.to_i

      # Verify that we're in a different process and have a new timer thread
      refute_equal parent_pid, child_pid
      refute_equal parent_timer_id, current_timer_id
      assert_equal 'true', is_running

      bucket.stop
    end
  end
end
