# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative 'annotate_traceparent'

module SolarWindsAPM
  module Patch
    module TagSql
      module SWOPgPatch
        EXEC_ISH_METHODS = %i[
          exec
          query
          sync_exec
          async_exec
          exec_params
          async_exec_params
          sync_exec_params
        ].freeze

        EXEC_ISH_METHODS.each do |method|
          define_method method do |*args, &block|
            traceparent = AnnotateTraceparent.generate_traceparent
            annotated_sql = ''
            sql = args[0]

            if traceparent.empty?
              annotated_sql = sql
            else
              annotated_traceparent = "traceparent='#{AnnotateTraceparent.generate_traceparent}'"

              current_span = ::OpenTelemetry::Trace.current_span
              attributes_dup = current_span.attributes.dup
              attributes_dup['sw.query_tag'] = "/*#{annotated_traceparent}*/"
              current_span.instance_variable_set(:@attributes, attributes_dup.freeze)

              annotated_sql = "#{sql} /*#{annotated_traceparent}*/"
            end

            args[0] = annotated_sql
            super(*args, &block)
          end
        end
      end
    end
  end
end

# need to prepend before pg instrumentation
PG::Connection.prepend(SolarWindsAPM::Patch::TagSql::SWOPgPatch) if defined?(PG::Connection)
