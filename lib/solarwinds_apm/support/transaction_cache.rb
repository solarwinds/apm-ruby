# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # LRU TransactionCache with initial limit 1000
  module TransactionCache
    attr_reader :capacity

    def self.initialize
      @capacity = 1000
      @cache = {}
      @order = []
    end

    def self.get(key)
      return nil unless @cache.key?(key)

      @order.delete(key)
      @order.push(key)
      @cache[key]
    end

    def self.del(key)
      @cache.delete(key)
      @order.delete(key)
    end

    def self.clear
      @cache.clear
      @order.clear
    end

    def self.size
      @cache.size
    end

    def self.set(key, value)
      if @cache.key?(key)
        @cache.delete(key)
      elsif @order.size >= @capacity
        evict_key = @order.shift
        @cache.delete(evict_key)
      end

      @cache[key] = value
      @order.push(key)
      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] current TransactionCache #{@cache.inspect}" }
    end
  end
end

SolarWindsAPM::TransactionCache.initialize
