# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patches
    module SWOPgConnectionPatch
      # this method is just save the traceparent comment before sanitization
      def obfuscate_sql(sql)
        if config[:db_statement] == :obfuscate
          extracted_comments = sql.match(TagSqlConstants::TRACEPARENT_REGEX)
          super + extracted_comments&.match(0).to_s
        else
          super
        end
      end
    end
  end
end

PG::Connection.prepend(SolarWindsAPM::Patches::SWOPgConnectionPatch) if defined?(PG::Connection) && defined?(OpenTelemetry::Instrumentation::PG::Patches::Connection)
