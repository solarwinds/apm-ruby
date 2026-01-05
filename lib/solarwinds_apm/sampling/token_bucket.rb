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
    attr_reader :type

    def initialize(token_bucket_settings)
      @capacity = token_bucket_settings.capacity || 0
      @rate = token_bucket_settings.rate || 0
      @tokens = @capacity
      @last_update_time = Time.now.to_f
      @type = token_bucket_settings.type
      @lock = Mutex.new
    end

    def capacity
      @lock.synchronize { @capacity }
    end

    def rate
      @lock.synchronize { @rate }
    end

    def tokens
      @lock.synchronize do
        calculate_tokens
        @tokens
      end
    end

    # oboe sampler update_settings will update the token
    def update(settings)
      settings.instance_of?(Hash) ? update_from_hash(settings) : update_from_hash(tb_to_hash(settings))
    end

    # Attempts to consume tokens from the bucket
    # @param token [Integer] Number of tokens to consume
    # @return [Boolean] Whether there were enough tokens
    def consume(token = 1)
      @lock.synchronize do
        calculate_tokens
        if @tokens >= token
          @tokens -= token
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] #{@type} Consumed #{token} from total #{@tokens} (#{(@tokens.to_f / @capacity * 100).round(1)}% remaining)" }
          true
        else
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] #{@type} Token consumption failed: requested=#{token}, available=#{@tokens}, capacity=#{@capacity}" }
          false
        end
      end
    end

    private

    def calculate_tokens
      now = Time.now.to_f
      elapsed = now - @last_update_time
      @last_update_time = now
      @tokens += elapsed * @rate
      @tokens = [@tokens, @capacity].min
    end

    # settings is from json sampler
    def update_from_hash(settings)
      @lock.synchronize do
        calculate_tokens

        if settings[:capacity]
          new_capacity = [0, settings[:capacity]].max
          difference = new_capacity - @capacity
          @capacity = new_capacity
          @tokens += difference
          @tokens = [0, @tokens].max
        end

        @rate = [0, settings[:rate]].max if settings[:rate]
      end
    end

    # settings is from http sampler
    def tb_to_hash(settings)
      tb_hash = {}
      tb_hash[:capacity] = settings.capacity if settings.respond_to?(:capacity)
      tb_hash[:rate] = settings.rate if settings.respond_to?(:rate)
      tb_hash[:type] = settings.type if settings.respond_to?(:type)
      tb_hash
    end
  end
end
