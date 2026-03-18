# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Patch
    module TagSql
      module SWODboUtils
        def self.annotate_span_and_sql(sql)
          return sql if sql.to_s.empty?

          current_span = ::OpenTelemetry::Trace.current_span

          annotated_sql = ''
          if current_span.context.trace_flags.sampled?
            traceparent = SolarWindsAPM::Utils.traceparent_from_context(current_span.context)
            annotated_traceparent = "/*traceparent='#{traceparent}'*/"
            current_span.add_attributes({ 'sw.query_tag' => annotated_traceparent })
            annotated_sql = "#{sql} #{annotated_traceparent}"
          else
            annotated_sql = sql
          end

          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] annotated_sql: #{annotated_sql}" }
          annotated_sql
        rescue StandardError => e
          SolarWindsAPM.logger.error { "[#{self.class}/#{__method__}] Failed to annotated sql. Error: #{e.message}" }
          sql
        end
      end
    end
  end
end
