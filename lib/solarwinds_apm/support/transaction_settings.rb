# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  class TransactionSettings
    SWO_TRACING_ENABLED      = 1
    SWO_TRACING_DISABLED     = 0

    def initialize(url_path: '', name: '', kind: '')
      @url_path = url_path
      @name     = name
      @kind     = kind
    end

    # calculate trace mode to set either 1 or 0 based on url_path and name+kind
    # first check if url_path match, if not match, then match the name+kind
    def calculate_trace_mode
      SolarWindsAPM::Config[:tracing_mode] == :enabled && tracing_enabled? ? SWO_TRACING_ENABLED : SWO_TRACING_DISABLED
    end

    private

    def tracing_enabled?
      span_layer = "#{@kind}:#{@name}"

      enabled_regexps  = SolarWindsAPM::Config[:enabled_regexps]
      disabled_regexps = SolarWindsAPM::Config[:disabled_regexps]

      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] enabled_regexps: #{enabled_regexps&.inspect}" }
      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] disabled_regexps: #{disabled_regexps&.inspect}" }

      return false if matches_any?(disabled_regexps, @url_path)
      return true  if matches_any?(enabled_regexps, @url_path)
      return false if matches_any?(disabled_regexps, span_layer)
      return true  if matches_any?(enabled_regexps, span_layer)

      true
    rescue StandardError => e
      SolarWindsAPM.logger.warn do
        "[#{self.class}/#{__method__}] Could not determine tracing status for #{@kind}. #{e.inspect}. transaction_settings regexps/extensions igonred/unfiltered."
      end
      true
    end

    # Checks if a given string matches any regex in a list.
    def matches_any?(regex_list, string_to_match)
      return false unless regex_list.is_a?(Array)
      regex_list.any? { |regex| regex.match?(string_to_match) }
    end
  end
end
