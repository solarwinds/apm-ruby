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
    MAX_INTERVAL = 2**31 - 1

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
      if settings[:capacity]
        difference = settings[:capacity] - @capacity
        self.capacity = settings[:capacity]
        self.tokens = @tokens + difference
      end

      self.rate = settings[:rate] if settings[:rate]

      if settings[:interval]
        self.interval = settings[:interval]
        if running
          stop
          start
        end
      end
    end

    def capacity=(n)
      @capacity = [0,n].max
    end

    def rate=(n)
      @rate = [0,n].max
    end

    def interval=(n)
      @interval = [0, [MAX_INTERVAL, n].min].max
    end

    def tokens=(n)
      @tokens = [0, [@capacity, n].min].max
    end

    # Attempts to consume tokens from the bucket
    # @param n [Integer] Number of tokens to consume
    # @return [Boolean] Whether there were enough tokens
    def consume(n = 1)
      if @tokens >= n
        self.tokens = @tokens - n
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
          sleep(@interval / 1000.0)
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
      self.tokens = self.tokens + @rate
    end
  end
end