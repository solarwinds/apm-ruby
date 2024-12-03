# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

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
