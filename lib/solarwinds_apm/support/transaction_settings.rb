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
      tracing_mode_enabled? && tracing_enabled? ? SWO_TRACING_ENABLED : SWO_TRACING_DISABLED
    end

    private

    def tracing_mode_enabled?
      SolarWindsAPM::Config[:tracing_mode] && ![:disabled, :never].include?(SolarWindsAPM::Config[:tracing_mode])
    end

    def tracing_enabled?
      span_layer = "#{@kind}:#{@name}"

      enabled_regexps  = SolarWindsAPM::Config[:enabled_regexps]
      disabled_regexps = SolarWindsAPM::Config[:disabled_regexps]

      SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] enabled_regexps: #{enabled_regexps&.inspect}"}
      SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] disabled_regexps: #{disabled_regexps&.inspect}"}

      return false if disabled_regexps.is_a?(Array) && disabled_regexps.any? { |regex| regex.match?(@url_path) }
      return true if enabled_regexps.is_a?(Array) && enabled_regexps.any? { |regex| regex.match?(@url_path) }
      return false if disabled_regexps.is_a?(Array) && disabled_regexps.any? { |regex| regex.match?(span_layer) }
      return true if enabled_regexps.is_a?(Array) && enabled_regexps.any? { |regex| regex.match?(span_layer) }

      true
    rescue StandardError => e
      SolarWindsAPM.logger.warn {"[#{self.class}/#{__method__}] Could not determine tracing status for #{kind}. #{e.inspect}. transaction_settings regexps/extensions igonred/unfiltered."}
      true
    end
  end
end
