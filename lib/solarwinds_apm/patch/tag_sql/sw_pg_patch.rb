# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patch
    module TagSql
      module SWOPgPatch
        # We target operations covered by the upstream pg instrumentation.
        # These are all alike in that they will have a SQL
        # statement as the first parameter, and they are all
        # non-prepared statement execute.
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
          define_method method do |*args|
            annotated_sql = ::SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql(args[0])
            args[0] = annotated_sql
            super(*args)
          end
        end
      end
    end
  end
end

# need to prepend before pg instrumentation patch itself
# upstream instrumentation -> our patch -> original function
PG::Connection.prepend(SolarWindsAPM::Patch::TagSql::SWOPgPatch) if defined?(PG::Connection)
