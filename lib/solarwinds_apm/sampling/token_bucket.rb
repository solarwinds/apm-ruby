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

    def initialize(token_bucket_settings)
      @lock = Mutex.new
      self.capacity = token_bucket_settings.capacity || 0
      self.rate = token_bucket_settings.rate || 0
      self.interval = token_bucket_settings.interval || MAX_INTERVAL
      self.tokens = capacity
      @stop_requested = false
      @timer = nil
    end

    # used call from update_settings e.g. bucket.update(bucket_settings)
    def update(settings)
      settings.instance_of?(Hash) ? update_from_hash(settings) : update_from_hash(tb_to_hash(settings))
    end

    def update_from_hash(settings)
      @lock.synchronize do
        if settings[:capacity]
          difference = settings[:capacity] - @capacity
          @capacity = [0, settings[:capacity]].max
          @tokens = (@tokens + difference).clamp(0, @capacity)
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Updated capacity: #{@capacity}, tokens: #{@tokens}, difference: #{difference}" }
        end

        if settings[:rate]
          @rate = [0, settings[:rate]].max
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Updated rate: #{@rate}" }
        end

        if settings[:interval]
          @interval = settings[:interval].clamp(0, MAX_INTERVAL)
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Updated interval: #{@interval}ms" }
        end
      end

      if settings[:interval] && running
        stop
        start
      end

      start unless running
    end

    def tb_to_hash(settings)
      { capacity: settings.capacity,
        rate: settings.rate,
        interval: settings.interval }
    end

    def capacity
      @lock.synchronize { @capacity }
    end

    def capacity=(capacity)
      @lock.synchronize { @capacity = [0, capacity].max }
    end

    def rate
      @lock.synchronize { @rate }
    end

    def rate=(rate)
      @lock.synchronize { @rate = [0, rate].max }
    end

    def interval
      @lock.synchronize { @interval }
    end

    def interval=(interval)
      @lock.synchronize { @interval = interval.clamp(0, MAX_INTERVAL) }
    end

    def tokens
      @lock.synchronize { @tokens }
    end

    def tokens=(tokens)
      @lock.synchronize { @tokens = tokens.clamp(0, @capacity) }
    end

    # Attempts to consume tokens from the bucket
    # @param n [Integer] Number of tokens to consume
    # @return [Boolean] Whether there were enough tokens
    def consume(token = 1)
      @lock.synchronize do
        if @tokens >= token
          @tokens -= token
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Consumed #{token} tokens, remaining: #{@tokens}/#{@capacity} (#{(@tokens.to_f / @capacity * 100).round(1)}%)" }
          true
        else
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Token consumption failed: requested=#{token}, available=#{@tokens}, capacity=#{@capacity}" }
          false
        end
      end
    end

    # Starts replenishing the bucket
    def start
      @lock.synchronize do
        return if running

        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Starting replenishment timer (interval: #{@interval}ms, rate: #{@rate})" }
        @stop_requested = false
      end

      @timer = Thread.new do
        loop do
          break if @stop_requested

          task
          sleep(@interval / 1000.0)
        end
      end
    end

    # Stops replenishing the bucket
    def stop
      @lock.synchronize do
        return unless running

        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Stopping replenishment timer" }
        @stop_requested = true
      end
      @timer.join # Wait for clean exit
      @lock.synchronize { @timer = nil }
    end

    # Whether the bucket is actively being replenished
    def running
      !@timer.nil? && @timer.alive?
    end

    private

    def task
      @lock.synchronize do
        @tokens = [@tokens + @rate, @capacity].min
      end
    end
  end
end
