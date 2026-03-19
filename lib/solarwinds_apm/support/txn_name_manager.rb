# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # Transaction Name Manager is sole for enabling solarwinds api to call set_transaction_name
  # 200 unique transaction naming per 60 seconds for the transaction naming.
  # Uses a single cleanup thread with a min-heap priority queue instead of
  # spawning one thread per unique transaction name.
  class TxnNameManager
    MAX_CARDINALITY = 200
    DEFAULT_TXN_NAME = 'other'
    TXN_NAME_POOL_TTL = 60 # 60s

    # @root_context_h is used for trace api set_transaction_name;
    #     it retrieve the span_id based on root trace_id
    #     set_root_context_h(trace_id, span_flags)
    # @cache store the transaction name that will be used for exporter
    #     to set transaction name for attributes, get by trace_span_id
    #     set(trace_span_id, transaction_name)
    # @transaction_name tracks known unique transaction names within the TTL window
    def initialize
      @cache = {}            # for mapping trace_span_id to transaction name
      @transaction_name = {} # maps txn_name -> expiry time (epoch seconds)
      @expiry_heap = []      # min-heap of [expiry_time, txn_name] for efficient cleanup
      @root_context_h = {}   # for set_transaction_name api call
      @mutex = Mutex.new
      @root_context_mutex = Mutex.new
      @cleanup_cond = ConditionVariable.new
      @cleanup_thread = nil
      @stopped = false
    end

    def get(key)
      @mutex.synchronize { @cache[key] }
    end

    def del(key)
      @mutex.synchronize { @cache.delete(key) }
    end

    def set(key, value)
      txn_name = value.slice(0, SolarWindsAPM::Constants::MAX_TXN_NAME_LENGTH)
      expiry = Time.now.to_i + TXN_NAME_POOL_TTL

      @mutex.synchronize do
        txn_name_exist = @transaction_name.key?(txn_name)

        if txn_name_exist || @transaction_name.size < MAX_CARDINALITY
          @cache[key] = txn_name
          @transaction_name[txn_name] = expiry
          heap_push([expiry, txn_name])
          ensure_cleanup_thread
          @cleanup_cond.signal
        else
          @cache[key] = DEFAULT_TXN_NAME
        end
      end

      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] txn manager current cache #{@cache.inspect}" }
    end

    alias []= set

    def set_root_context_h(key, value)
      @root_context_mutex.synchronize do
        @root_context_h[key] = value
      end
      SolarWindsAPM.logger.debug do
        "[#{self.class}/#{__method__}] txn manager current root_context_h #{@root_context_h.inspect}"
      end
    end

    def get_root_context_h(key)
      @root_context_mutex.synchronize { @root_context_h[key] }
    end

    def delete_root_context_h(key)
      @root_context_mutex.synchronize do
        @root_context_h.delete(key)
      end
    end

    # Stops the cleanup thread. Call on shutdown to avoid thread leakage.
    def stop
      @mutex.synchronize do
        @stopped = true
        @cleanup_cond.signal
      end
      @cleanup_thread&.join
    end

    private

    def ensure_cleanup_thread
      return if @cleanup_thread&.alive?

      @cleanup_thread = Thread.new { cleanup_loop }
      @cleanup_thread.abort_on_exception = false
    end

    # Single long-lived thread that sleeps until the next expiry, then
    # removes all expired transaction names from the pool.
    def cleanup_loop
      @mutex.synchronize do
        until @stopped
          purge_expired_entries

          if @expiry_heap.empty?
            @cleanup_cond.wait(@mutex)
          else
            wait_seconds = [@expiry_heap.first[0] - Time.now.to_i, 0].max
            @cleanup_cond.wait(@mutex, wait_seconds) if wait_seconds.positive?
          end
        end
      end
    rescue StandardError => e
      SolarWindsAPM.logger.warn { "[#{self.class}/#{__method__}] cleanup thread error: #{e.message}" }
    end

    def purge_expired_entries
      now = Time.now.to_i
      while (entry = @expiry_heap.first)
        break if entry[0] > now

        heap_pop
        txn_name = entry[1]
        # Only delete if the recorded expiry matches (not renewed)
        @transaction_name.delete(txn_name) if @transaction_name[txn_name] == entry[0]
      end
    end

    # Min-heap operations (heap ordered by expiry time)
    def heap_push(entry)
      @expiry_heap << entry
      sift_up(@expiry_heap.size - 1)
    end

    def heap_pop
      return if @expiry_heap.empty?

      swap(0, @expiry_heap.size - 1)
      result = @expiry_heap.pop
      sift_down(0)
      result
    end

    def sift_up(idx)
      while idx.positive?
        parent = (idx - 1) / 2
        break if @expiry_heap[parent][0] <= @expiry_heap[idx][0]

        swap(idx, parent)
        idx = parent
      end
    end

    def sift_down(idx)
      size = @expiry_heap.size
      loop do
        smallest = idx
        left = (2 * idx) + 1
        right = (2 * idx) + 2
        smallest = left if left < size && @expiry_heap[left][0] < @expiry_heap[smallest][0]
        smallest = right if right < size && @expiry_heap[right][0] < @expiry_heap[smallest][0]
        break if smallest == idx

        swap(idx, smallest)
        idx = smallest
      end
    end

    def swap(idx_i, idx_j)
      @expiry_heap[idx_i], @expiry_heap[idx_j] = @expiry_heap[idx_j], @expiry_heap[idx_i]
    end
  end
end
