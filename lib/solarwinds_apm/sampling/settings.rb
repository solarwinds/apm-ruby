# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module SamplingSettings
    def self.merge(remote, local)
      flags = local[:tracing_mode] || remote[:flags]

      if local[:trigger_mode] == :enabled
        flags |= SolarWindsAPM::Flags::TRIGGERED_TRACE
      elsif local[:trigger_mode] == :disabled
        flags &= ~ SolarWindsAPM::Flags::TRIGGERED_TRACE
      end

      if remote[:flags].anybits?(SolarWindsAPM::Flags::OVERRIDE)
        flags &= remote[:flags]
        flags |= SolarWindsAPM::Flags::OVERRIDE
      end

      remote.merge(flags: flags)
    end
  end
end
