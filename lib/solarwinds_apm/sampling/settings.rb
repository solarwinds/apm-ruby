# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module SamplingSettings
    # Merges remote (server-side) and local (config-based) sampling settings.
    #
    # Precedence algorithm:
    # 1. Start with local tracing_mode flags if set, otherwise use remote flags as baseline.
    # 2. Apply local trigger_mode: set or clear the TRIGGERED_TRACE bit accordingly.
    # 3. If the remote OVERRIDE bit is set, the remote flags take precedence:
    #    AND remote flags into the result (masking out locally-enabled bits the server disallows),
    #    then re-set the OVERRIDE bit to preserve it in the final result.
    #
    # Bit layout (see SolarWindsAPM::Flags):
    #   SAMPLE_START          - enables dice-roll sampling
    #   SAMPLE_THROUGH_ALWAYS - enables parent-based pass-through
    #   TRIGGERED_TRACE       - enables trigger tracing
    #   OVERRIDE              - server override; remote flags mask local flags
    def self.merge(remote, local)
      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] SamplingSettings merge with remote: #{remote.inspect}; local: #{local.inspect}" }

      # Step 1: Use local tracing_mode as baseline flags, fall back to remote flags
      flags = local[:tracing_mode] || remote[:flags]

      # Step 2: Apply local trigger_mode by setting or clearing the TRIGGERED_TRACE bit
      if local[:trigger_mode] == :enabled
        flags |= SolarWindsAPM::Flags::TRIGGERED_TRACE       # set the trigger trace bit
      elsif local[:trigger_mode] == :disabled
        flags &= ~SolarWindsAPM::Flags::TRIGGERED_TRACE      # clear the trigger trace bit
      end

      # Step 3: If remote has OVERRIDE set, remote flags take precedence.
      # AND with remote flags to mask out any locally-enabled bits the server disallows,
      # then re-set OVERRIDE so downstream code knows the override was applied.
      if remote[:flags].anybits?(SolarWindsAPM::Flags::OVERRIDE)
        flags &= remote[:flags]                              # mask: only keep bits allowed by remote
        flags |= SolarWindsAPM::Flags::OVERRIDE              # preserve the override indicator
      end

      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] final flags: #{flags}" }
      remote.merge(flags: flags)
    end
  end
end
