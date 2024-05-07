# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # SolarWindsTxnNameManager
  # Transaction Name Manager is sole for enabling solarwinds api to call set_transaction_name
  class TxnNameManager
    def initialize
      @cache = {}
      @root_context_h = {}
      @mutex = Mutex.new
    end

    def get(key)
      @cache[key]
    end

    def del(key)
      @cache.delete(key)
    end

    def set(key, value)
      @cache[key] = value
      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] txn manager current cache #{@cache.inspect}" }
    end

    alias []= set

    def set_root_context_h(key, value)
      @mutex.synchronize do
        @root_context_h[key] = value
      end
      SolarWindsAPM.logger.debug do
        "[#{self.class}/#{__method__}] txn manager current root_context_h #{@root_context_h.inspect}"
      end
    end

    def get_root_context_h(key)
      @root_context_h[key]
    end

    def delete_root_context_h(key)
      @mutex.synchronize do
        @root_context_h.delete(key)
      end
    end
  end
end
