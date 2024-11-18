# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Patch
    module TagSql
      module SWOMysql2Patch
        def query(sql, options = {})
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

          super(annotated_sql, options)
        end
      end
    end
  end
end

# need to prepend before mysql2 instrumentation prepend the original function
# after entire process, the call sequence will be:
# upstream instrumentation -> our patch -> original function
Mysql2::Client.prepend(SolarWindsAPM::Patch::TagSql::SWOMysql2Patch) if defined?(Mysql2::Client)
