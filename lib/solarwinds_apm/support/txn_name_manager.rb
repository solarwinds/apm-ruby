# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # Transaction Name Manager is sole for enabling solarwinds api to call set_transaction_name
  # 200 unique transaction naming per 60 seconds for the transaction naming
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
    # @transaction_name store the transaction name and its expire call
    #     set(transaction_name, thread {@cache.del()})
    def initialize
      @cache = {}            # for mapping trace_span_id to transaction name
      @transaction_name = {} # only make sure the cardinality requirement that 200 unique txn within 60s
      # use for setting DEFAULT_TXN_NAME (in @cache) when cardinality reach the maximal
      @root_context_h = {} # for set_transaction_name api call
      @mutex = Mutex.new
      @root_context_mutex = Mutex.new
    end

    def get(key)
      @mutex.synchronize { @cache[key] }
    end

    def del(key)
      @mutex.synchronize { @cache.delete(key) }
    end

    def set(key, value)
      # new name and room in pool -> add name to pool and schedule for removal after ttl -> return name
      # new name but no room in pool -> return default name
      # existing name -> cancel previously scheduled removal -> schedule new removal -> return name
      txn_name = value.slice(0, SolarWindsAPM::Constants::MAX_TXN_NAME_LENGTH)
      txn_name_exist = false

      # thread exit execute ensure block, better option than kill for sleep
      @mutex.synchronize do
        if @transaction_name[txn_name]
          txn_name_exist = true
          @transaction_name[txn_name].exit
        end

        if txn_name_exist || @transaction_name.size < MAX_CARDINALITY
          @cache[key] = txn_name
          @transaction_name[txn_name] = Thread.new { cleanup_txn(key, txn_name) }
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

    def cleanup_txn(_key, txn_name)
      sleep(TXN_NAME_POOL_TTL)
    ensure
      @mutex.synchronize do
        @transaction_name.delete(txn_name)
      end
    end
  end
end
