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

          ::OpenTelemetry::Trace.current_span
          transparent = annotated_traceparent

          annotated_sql = ''
          annotated_sql = if transparent.empty?
                            sql
                          else
                            "#{sql} #{transparent}"
                          end

          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] annotated_sql: #{annotated_sql}" }
          annotated_sql
        rescue StandardError => e
          SolarWindsAPM.logger.error { "[#{self.class}/#{__method__}] Failed to annotated sql. Error: #{e.message}" }
          sql
        end

        def self.annotated_traceparent
          current_span = ::OpenTelemetry::Trace.current_span
          if current_span.context.trace_flags.sampled?
            traceparent = SolarWindsAPM::Utils.traceparent_from_context(current_span.context)
            current_span.add_attributes({ 'sw.query_tag' => "/*traceparent='#{traceparent}'*/" })
            "/*traceparent='#{traceparent}'*/"
          else
            ''
          end
        end
      end
    end
  end
end
