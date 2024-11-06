# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative 'annotate_traceparent'

module SolarWindsAPM
  module Patch
    module TagSql
      module SWOMysql2Patch
        def query(sql, options = {})
          traceparent = AnnotateTraceparent.generate_traceparent
          annotated_sql = ''

          if traceparent.empty?
            annotated_sql = sql
          else
            annotated_traceparent = "traceparent='#{AnnotateTraceparent.generate_traceparent}'"

            current_span = ::OpenTelemetry::Trace.current_span
            current_span.add_attributes({ 'sw.query_tag' => "/*#{annotated_traceparent}*/" })

            annotated_sql = "#{sql} /*#{annotated_traceparent}*/"
          end

          super(annotated_sql, options)
        end
      end
    end
  end
end

# need to prepend before mysql2 instrumentation
# so they will call this query function before
# reach to original query function
Mysql2::Client.prepend(SolarWindsAPM::Patch::TagSql::SWOMysql2Patch) if defined?(Mysql2::Client)
