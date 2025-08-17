# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Bucket is used to consume that determine if capacity is enough
# capacity is updated through update_settings
module SolarWindsAPM
  class TokenBucket
    # Maximum value of a signed 32-bit integer
    MAX_INTERVAL = (2**31) - 1

    attr_reader :capacity, :rate, :interval, :tokens

    def initialize(token_bucket_settings)
      self.capacity = token_bucket_settings.capacity || 0
      self.rate = token_bucket_settings.rate || 0
      self.interval = token_bucket_settings.interval || MAX_INTERVAL
      self.tokens = @capacity
      @timer = nil
    end

    # used call from update_settings e.g. bucket.update(bucket_settings)
    def update(settings)
      settings.instance_of?(Hash) ? update_from_hash(settings) : update_from_token_bucket_settings(settings)
    end

    def update_from_hash(settings)
      if settings[:capacity]
        difference = settings[:capacity] - @capacity
        self.capacity = settings[:capacity]
        self.tokens = @tokens + difference
      end

      self.rate = settings[:rate] if settings[:rate]

      return unless settings[:interval]

      self.interval = settings[:interval]
      return unless running

      stop
      start
    end

    def update_from_token_bucket_settings(settings)
      if settings.capacity
        difference = settings.capacity - @capacity
        self.capacity = settings.capacity
        self.tokens = @tokens + difference
      end

      self.rate = settings.rate if settings.rate

      return unless settings.interval

      self.interval = settings.interval
      return unless running

      stop
      start
    end

    def capacity=(capacity)
      @capacity = [0, capacity].max
    end

    def rate=(rate)
      @rate = [0, rate].max
    end

    # self.interval= sets the @interval and @sleep_interval
    # @sleep_interval is used in the timer thread to sleep between replenishing the bucket
    def interval=(interval)
      @interval = interval.clamp(0, MAX_INTERVAL)
      @sleep_interval = @interval / 1000.0
    end

    def tokens=(tokens)
      @tokens = tokens.clamp(0, @capacity)
    end

    # Attempts to consume tokens from the bucket
    # @param n [Integer] Number of tokens to consume
    # @return [Boolean] Whether there were enough tokens
    def consume(token = 1)
      if @tokens >= token
        self.tokens = @tokens - token
        true
      else
        false
      end
    end

    # Starts replenishing the bucket
    def start
      return if running

      @timer = Thread.new do
        loop do
          task
          sleep(@sleep_interval)
        end
      end
    end

    # Stops replenishing the bucket
    def stop
      return unless running

      @timer.kill
      @timer = nil
    end

    # Whether the bucket is actively being replenished
    def running
      !@timer.nil?
    end

    private

    def task
      self.tokens = tokens + @rate
    end
  end
end
