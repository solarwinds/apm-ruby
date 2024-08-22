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
          extracted_comments = sql.match(/\/\*\s*traceparent=?'?[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}'?\s*\*\//)
          super(sql) + extracted_comments&.match(0).to_s
        else
          super(sql)
        end
      end
    end
  end
end

::PG::Connection.prepend(SolarWindsAPM::Patches::SWOPgConnectionPatch) if defined?(::PG::Connection) && defined?(OpenTelemetry::Instrumentation::PG::Patches::Connection)	
