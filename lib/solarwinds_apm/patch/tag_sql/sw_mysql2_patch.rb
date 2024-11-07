# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

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
