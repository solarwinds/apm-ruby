# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # Utils
  class Utils
    VERSION = '00'

    def self.trace_state_header(trace_state)
      return nil if trace_state.nil? || trace_state.empty?

      arr = trace_state.to_h.map { |key, value| "#{key}=#{value}" }
      header = arr.join(',')
      SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] generated trace_state_header: #{header}" }
      header
    end

    # Generates a liboboe W3C compatible trace_context from provided OTel span context.
    def self.traceparent_from_context(span_context)
      flag = span_context.trace_flags.sampled? ? 1 : 0
      xtr = "#{VERSION}-#{span_context.hex_trace_id}-#{span_context.hex_span_id}-0#{flag}"
      SolarWindsAPM.logger.debug do
        "[#{name}/#{__method__}] generated traceparent: #{xtr} from #{span_context.inspect}"
      end
      xtr
    end

    def self.determine_lambda_env
      if ENV['LAMBDA_TASK_ROOT'].to_s.empty? && ENV['AWS_LAMBDA_FUNCTION_NAME'].to_s.empty?
        false
      else
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] lambda environment - LAMBDA_TASK_ROOT: #{ENV.fetch('LAMBDA_TASK_ROOT', nil)}; AWS_LAMBDA_FUNCTION_NAME: #{ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)}" }
        true
      end
    end
  end
end
