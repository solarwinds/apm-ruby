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

      local[:trigger_mode] ? flags |= ::Flags::TRIGGERED_TRACE : flags &= ~::Flags::TRIGGERED_TRACE

      if (remote[:flags] & ::Flags::OVERRIDE) != 0
        flags &= remote[:flags]
        flags |= ::Flags::OVERRIDE
      end

      remote.dup.tap { |merged| merged[:flags] = flags }
    end
  end
end
