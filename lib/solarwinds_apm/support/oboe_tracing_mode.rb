# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # OboeTracingMode
  # Used in solarwinds_sampler
  class OboeTracingMode
    OBOE_SETTINGS_UNSET = -1
    OBOE_TRACE_DISABLED = 0
    OBOE_TRACE_ENABLED = 1
    OBOE_TRIGGER_DISABLED = 0
    OBOE_TRIGGER_ENABLED = 1

    def self.get_oboe_trace_mode(tracing_mode)
      mode = OBOE_SETTINGS_UNSET
      mode = OBOE_TRACE_ENABLED if tracing_mode == :enabled
      mode = OBOE_TRACE_DISABLED if tracing_mode == :disabled
      mode
    end

    def self.get_oboe_trigger_trace_mode(trigger_trace_mode)
      mode = OBOE_SETTINGS_UNSET
      mode = OBOE_TRIGGER_ENABLED if trigger_trace_mode == :enabled
      mode = OBOE_TRIGGER_DISABLED if trigger_trace_mode == :disabled
      mode
    end
  end
end
