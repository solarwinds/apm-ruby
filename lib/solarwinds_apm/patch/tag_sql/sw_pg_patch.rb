# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative 'swo_dbo_utils'

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
            annotated_sql = ::SolarWindsAPM::Patch::TagSql::SWODboUtils.annotate_span_and_sql(args[0])
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
